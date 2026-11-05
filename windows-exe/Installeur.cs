// Installeur de Tour de contrôle (Windows) : une fenêtre, sans console.
// 1. Connexion à GitHub avec le compte de la personne (code à saisir sur github.com).
// 2. Téléchargement de la dernière version depuis le dépôt privé, vérification de son empreinte.
// 3. Installation par l'installeur du paquet (Programs, raccourcis), puis ouverture de l'appli.
// Aucun mot de passe ni accès n'est enregistré : l'accès GitHub sert seulement au téléchargement.
// Compilé avec le compilateur C# 5 livré avec Windows (voir construire.cmd).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

static class Programme {
  [STAThread]
  static void Main() {
    ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
    Application.EnableVisualStyles();
    Application.SetCompatibleTextRenderingDefault(false);
    Application.Run(new Fenetre());
  }
}

class Fenetre : Form {
  const string ClientId = "Ov23liBDVeFgmsICJVYN";
  const string Depot = "Steven30878/tour-de-controle-maj";
  const string Agent = "tour-de-controle-installeur";

  readonly RadioButton vendable = new RadioButton();
  readonly RadioButton perso = new RadioButton();
  readonly Button installer = new Button();
  readonly Label etat = new Label();
  readonly TextBox code = new TextBox();
  readonly Button ouvrir = new Button();
  readonly ProgressBar barre = new ProgressBar();
  readonly JavaScriptSerializer json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
  string pageCode;

  public Fenetre() {
    Text = "Installer Tour de contrôle";
    try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
    FormBorderStyle = FormBorderStyle.FixedDialog;
    MaximizeBox = false;
    StartPosition = FormStartPosition.CenterScreen;
    ClientSize = new Size(520, 360);
    Font = new Font("Segoe UI", 10f);

    var titre = new Label { Text = "Tour de contrôle", Font = new Font("Segoe UI Semibold", 16f), Location = new Point(24, 18), AutoSize = true };
    var intro = new Label {
      Text = "L'installeur télécharge la dernière version depuis le dépôt GitHub privé.\nIl faut un compte GitHub invité sur ce dépôt.",
      Location = new Point(26, 56), Size = new Size(470, 44)
    };
    vendable.Text = "Édition clé API (pour tout le monde)";
    vendable.Location = new Point(28, 108); vendable.AutoSize = true; vendable.Checked = true;
    perso.Text = "Édition perso (réservée à la personne qui fait les mises à jour)";
    perso.Location = new Point(28, 134); perso.AutoSize = true;

    installer.Text = "Se connecter à GitHub et installer";
    installer.Location = new Point(26, 170); installer.Size = new Size(300, 34);
    installer.Click += async (s, e) => await Lancer();

    code.ReadOnly = true; code.BorderStyle = BorderStyle.None; code.BackColor = BackColor;
    code.Font = new Font("Consolas", 22f, FontStyle.Bold); code.TextAlign = HorizontalAlignment.Center;
    code.Location = new Point(26, 220); code.Size = new Size(300, 40); code.Visible = false;
    ouvrir.Text = "Ouvrir la page GitHub";
    ouvrir.Location = new Point(340, 222); ouvrir.Size = new Size(156, 34); ouvrir.Visible = false;
    ouvrir.Click += (s, e) => { if (pageCode != null) Process.Start(pageCode); };

    barre.Location = new Point(26, 276); barre.Size = new Size(470, 18); barre.Visible = false;
    etat.Location = new Point(26, 300); etat.Size = new Size(470, 48);

    Controls.AddRange(new Control[] { titre, intro, vendable, perso, installer, code, ouvrir, barre, etat });
  }

  void Etat(string texte) { etat.Text = texte; }

  async Task Lancer() {
    installer.Enabled = false; vendable.Enabled = false; perso.Enabled = false;
    string edition = perso.Checked ? "perso" : "vendable";
    try {
      string jeton = await Connexion();
      await Installation(jeton, edition);
    } catch (Exception ex) {
      code.Visible = false; ouvrir.Visible = false; barre.Visible = false;
      Etat("Erreur : " + ex.Message);
      MessageBox.Show(this, ex.Message, "Installation impossible", MessageBoxButtons.OK, MessageBoxIcon.Error);
      installer.Enabled = true; vendable.Enabled = true; perso.Enabled = true;
    }
  }

  static HttpClient Client(bool suivre) {
    var c = new HttpClient(new HttpClientHandler { AllowAutoRedirect = suivre });
    c.DefaultRequestHeaders.UserAgent.ParseAdd(Agent);
    c.Timeout = TimeSpan.FromMinutes(30);
    return c;
  }

  async Task<Dictionary<string, object>> PostForm(string url, Dictionary<string, string> champs) {
    using (var c = Client(true)) {
      var req = new HttpRequestMessage(HttpMethod.Post, url) { Content = new FormUrlEncodedContent(champs) };
      req.Headers.Accept.ParseAdd("application/json");
      var r = await c.SendAsync(req);
      string texte = await r.Content.ReadAsStringAsync();
      return json.Deserialize<Dictionary<string, object>>(texte);
    }
  }

  static string S(Dictionary<string, object> d, string cle) {
    object v;
    return d != null && d.TryGetValue(cle, out v) && v != null ? Convert.ToString(v) : null;
  }

  async Task<string> Connexion() {
    Etat("Connexion à GitHub…");
    var d = await PostForm("https://github.com/login/device/code", new Dictionary<string, string> { { "client_id", ClientId }, { "scope", "repo" } });
    string deviceCode = S(d, "device_code");
    if (deviceCode == null) throw new Exception("GitHub n'a pas donné de code de connexion. Vérifie ta connexion internet.");
    pageCode = S(d, "verification_uri");
    code.Text = S(d, "user_code");
    code.Visible = true; ouvrir.Visible = true;
    try { Clipboard.SetText(code.Text); } catch { }
    Etat("Sur la page GitHub qui s'ouvre, saisis ce code (il est déjà copié : Ctrl+V), puis autorise Tour de contrôle.");
    Process.Start(pageCode);

    int attente = Math.Max(5, int.Parse(S(d, "interval") ?? "5"));
    DateTime fin = DateTime.Now.AddSeconds(int.Parse(S(d, "expires_in") ?? "900"));
    while (DateTime.Now < fin) {
      await Task.Delay(attente * 1000);
      Dictionary<string, object> t;
      try {
        t = await PostForm("https://github.com/login/oauth/access_token", new Dictionary<string, string> {
          { "client_id", ClientId }, { "device_code", deviceCode }, { "grant_type", "urn:ietf:params:oauth:grant-type:device_code" } });
      } catch { continue; }
      string jeton = S(t, "access_token");
      if (jeton != null) { code.Visible = false; ouvrir.Visible = false; return jeton; }
      string erreur = S(t, "error");
      if (erreur == "slow_down") attente += 5;
      else if (erreur != "authorization_pending") throw new Exception("Connexion refusée ou expirée (" + erreur + "). Relance l'installeur.");
    }
    throw new Exception("Le code a expiré. Relance l'installeur.");
  }

  async Task<Dictionary<string, object>> Api(string jeton, string chemin) {
    using (var c = Client(true)) {
      var req = new HttpRequestMessage(HttpMethod.Get, "https://api.github.com" + chemin);
      req.Headers.Accept.ParseAdd("application/vnd.github+json");
      req.Headers.Add("Authorization", "Bearer " + jeton);
      var r = await c.SendAsync(req);
      if ((int)r.StatusCode == 404) throw new Exception("Ton compte GitHub n'est pas invité sur le dépôt " + Depot + ". Demande une invitation, accepte-la (mail de GitHub), puis relance.");
      if (!r.IsSuccessStatusCode) throw new Exception("GitHub a répondu " + (int)r.StatusCode + ".");
      return json.Deserialize<Dictionary<string, object>>(await r.Content.ReadAsStringAsync());
    }
  }

  // Un fichier de la publication : GitHub renvoie vers son stockage, où l'accès n'est pas envoyé.
  async Task Fichier(string jeton, Dictionary<string, object> pub, string nom, string dest, bool progression) {
    var assets = (System.Collections.ArrayList)pub["assets"];
    Dictionary<string, object> a = null;
    foreach (Dictionary<string, object> x in assets) if (S(x, "name") == nom) { a = x; break; }
    if (a == null) throw new Exception(nom + " est absent de la dernière version.");
    string adresse;
    using (var c = Client(false)) {
      var req = new HttpRequestMessage(HttpMethod.Get, S(a, "url"));
      req.Headers.Accept.ParseAdd("application/octet-stream");
      req.Headers.Add("Authorization", "Bearer " + jeton);
      var r = await c.SendAsync(req);
      if (r.Headers.Location == null) throw new Exception("Téléchargement de " + nom + " refusé par GitHub (" + (int)r.StatusCode + ").");
      adresse = r.Headers.Location.ToString();
    }
    using (var c = Client(true))
    using (var r = await c.GetAsync(adresse, HttpCompletionOption.ResponseHeadersRead)) {
      r.EnsureSuccessStatusCode();
      long total = r.Content.Headers.ContentLength ?? 0;
      using (var src = await r.Content.ReadAsStreamAsync())
      using (var fs = File.Create(dest)) {
        var buf = new byte[1 << 20];
        long lu = 0; int n;
        while ((n = await src.ReadAsync(buf, 0, buf.Length)) > 0) {
          await fs.WriteAsync(buf, 0, n);
          lu += n;
          if (progression && total > 0) {
            barre.Value = (int)(lu * 100 / total);
            Etat("Téléchargement : " + (lu / 1000000) + " / " + (total / 1000000) + " Mo");
          }
        }
      }
    }
  }

  async Task Installation(string jeton, string edition) {
    Etat("Recherche de la dernière version…");
    var pub = await Api(jeton, "/repos/" + Depot + "/releases/latest");
    string dossier = Path.Combine(Path.GetTempPath(), "tour-de-controle-installeur");
    if (Directory.Exists(dossier)) Directory.Delete(dossier, true);
    Directory.CreateDirectory(dossier);

    string fManifeste = Path.Combine(dossier, "manifeste.json");
    await Fichier(jeton, pub, "manifest-" + edition + ".json", fManifeste, false);
    var m = json.Deserialize<Dictionary<string, object>>(File.ReadAllText(fManifeste));
    string nom = S(m, "file"), empreinte = (S(m, "sha256") ?? "").ToLowerInvariant(), version = S(m, "version");
    if (nom == null || empreinte.Length != 64) throw new Exception("Les informations de la version sont illisibles.");

    barre.Visible = true; barre.Value = 0;
    string paquet = Path.Combine(dossier, nom);
    await Fichier(jeton, pub, nom, paquet, true);

    Etat("Vérification du paquet…");
    string calcul;
    using (var sha = SHA256.Create())
    using (var fs = File.OpenRead(paquet)) calcul = BitConverter.ToString(await Task.Run(() => sha.ComputeHash(fs))).Replace("-", "").ToLowerInvariant();
    if (calcul != empreinte) throw new Exception("Le paquet téléchargé est abîmé ou modifié (empreinte différente). Relance l'installeur.");

    Etat("Décompression…");
    string contenu = Path.Combine(dossier, "paquet");
    Directory.CreateDirectory(contenu);
    string tar = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "tar.exe");
    if (await Executer(tar, "-x -f \"" + paquet + "\" -C \"" + contenu + "\"") != 0) throw new Exception("Décompression impossible.");

    Etat("Installation…");
    string script = Path.Combine(contenu, "installer.ps1");
    if (await Executer("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"") != 0) throw new Exception("L'installation a échoué.");
    try { Directory.Delete(dossier, true); } catch { }

    barre.Value = 100;
    Etat("Tour de contrôle " + version + " est installé.");
    MessageBox.Show(this, "Tour de contrôle " + version + " est installé et va s'ouvrir.\n\nDans l'appli : Paramètres > Version et mises à jour > Se connecter à GitHub, pour recevoir les mises à jour.", "Installation terminée", MessageBoxButtons.OK, MessageBoxIcon.Information);
    Close();
  }

  static Task<int> Executer(string programme, string arguments) {
    return Task.Run(() => {
      var p = Process.Start(new ProcessStartInfo(programme, arguments) { UseShellExecute = false, CreateNoWindow = true });
      p.WaitForExit();
      return p.ExitCode;
    });
  }
}
