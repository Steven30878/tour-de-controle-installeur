// Fabrique les installeurs à publier dans dist/ :
// - Installer-Tour-de-controle-Windows.zip : le .exe (compilé par windows-exe/construire.cmd) ;
// - Installer-Tour-de-controle-Mac.tar.gz : « Installer Tour de contrôle.app », dont l'exécutable
//   est mac-app/installer.sh (droits d'exécution gardés grâce au .tar.gz).
// Réutilise les outils du projet Tour de contrôle (lib-archive, icône, resvg, plist).
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const here = __dirname;
const tdc = path.join(here, '..', 'tour-de-controle');
const req = (m) => require(path.join(tdc, 'node_modules', m));
const { writeTgz } = require(path.join(tdc, 'scripts', 'lib-archive.cjs'));
const plist = req('plist');
const { Resvg } = req('@resvg/resvg-js');
const dist = path.join(here, 'dist');
fs.mkdirSync(dist, { recursive: true });

// --- Windows -----------------------------------------------------------------------------
const exe = path.join(here, 'windows-exe', 'Installer Tour de controle.exe');
if (!fs.existsSync(exe)) throw new Error('Compile d’abord windows-exe (construire.cmd).');
const winZip = path.join(dist, 'Installer-Tour-de-controle-Windows.zip');
fs.rmSync(winZip, { force: true });
execFileSync(path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe'), ['-a', '-c', '-f', winZip, '-C', path.dirname(exe), path.basename(exe)]);

// --- Mac ---------------------------------------------------------------------------------
function icns() {
  const svg = fs.readFileSync(path.join(tdc, 'build', 'icon.svg'));
  const types = [['icp4', 16], ['icp5', 32], ['ic07', 128], ['ic08', 256], ['ic09', 512], ['ic10', 1024], ['ic11', 32], ['ic12', 64], ['ic13', 256], ['ic14', 512]];
  const parts = types.map(([type, size]) => {
    const png = new Resvg(svg, { fitTo: { mode: 'width', value: size } }).render().asPng();
    const h = Buffer.alloc(8);
    h.write(type, 0, 'ascii');
    h.writeUInt32BE(png.length + 8, 4);
    return Buffer.concat([h, png]);
  });
  const body = Buffer.concat(parts);
  const h = Buffer.alloc(8);
  h.write('icns', 0, 'ascii');
  h.writeUInt32BE(body.length + 8, 4);
  return Buffer.concat([h, body]);
}
const app = 'Installer Tour de contrôle.app';
const info = plist.build({
  CFBundleName: 'Installer Tour de contrôle',
  CFBundleDisplayName: 'Installer Tour de contrôle',
  CFBundleIdentifier: 'com.ethan.tour-de-controle.installeur',
  CFBundleExecutable: 'installer',
  CFBundleIconFile: 'AppIcon',
  CFBundlePackageType: 'APPL',
  CFBundleShortVersionString: '2.0',
  CFBundleVersion: '2',
  LSMinimumSystemVersion: '13.0',
  NSHighResolutionCapable: true,
});
const script = fs.readFileSync(path.join(here, 'mac-app', 'installer.sh'), 'utf8').replace(/\r\n/g, '\n');
const entry = (name, mode, type, data) => ({ name, mode, type, data: () => data });
const entries = [
  entry(app, 0o755, 'dir', Buffer.alloc(0)),
  entry(`${app}/Contents`, 0o755, 'dir', Buffer.alloc(0)),
  entry(`${app}/Contents/MacOS`, 0o755, 'dir', Buffer.alloc(0)),
  entry(`${app}/Contents/Resources`, 0o755, 'dir', Buffer.alloc(0)),
  entry(`${app}/Contents/Info.plist`, 0o644, 'file', Buffer.from(info, 'utf8')),
  entry(`${app}/Contents/MacOS/installer`, 0o755, 'file', Buffer.from(script, 'utf8')),
  entry(`${app}/Contents/Resources/AppIcon.icns`, 0o644, 'file', icns()),
];
const macTgz = path.join(dist, 'Installer-Tour-de-controle-Mac.tar.gz');
writeTgz(macTgz, entries).then(() => {
  for (const f of fs.readdirSync(dist)) console.log(`${f} : ${(fs.statSync(path.join(dist, f)).size / 1000).toFixed(0)} Ko`);
});
