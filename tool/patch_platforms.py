"""Aplica a las carpetas generadas por `flutter create` los permisos y ajustes que Coachless necesita.

Se ejecuta en GitHub Actions después de `flutter create .` y antes de compilar.
Es idempotente: se puede correr varias veces sin duplicar nada.
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent


def patch_file(path: pathlib.Path, fn):
    if not path.exists():
        print(f"(omitido, no existe) {path}")
        return
    old = path.read_text(encoding="utf-8")
    new = fn(old)
    if new != old:
        path.write_text(new, encoding="utf-8")
        print(f"actualizado: {path}")


# ---------------- Android ----------------
ANDROID_PERMS = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.health.READ_STEPS",
    "android.permission.health.READ_HEART_RATE",
    "android.permission.health.READ_RESTING_HEART_RATE",
    "android.permission.health.READ_ACTIVE_CALORIES_BURNED",
    "android.permission.health.READ_TOTAL_CALORIES_BURNED",
    "android.permission.health.READ_SLEEP",
    "android.permission.health.READ_EXERCISE",
    "android.permission.health.READ_WEIGHT",
    "android.permission.health.READ_BODY_FAT",
]


def manifest(xml: str) -> str:
    xml = re.sub(r'android:label="[^"]*"', 'android:label="Coachless"', xml, count=1)
    for p in ANDROID_PERMS:
        tag = f'<uses-permission android:name="{p}"/>'
        if p not in xml:
            xml = xml.replace("<application", f"{tag}\n    <application", 1)
    if "com.google.android.apps.healthdata" not in xml:
        queries = (
            "<queries>\n"
            '        <package android:name="com.google.android.apps.healthdata"/>\n'
            "        <intent>\n"
            '            <action android:name="android.intent.action.VIEW"/>\n'
            '            <data android:scheme="https"/>\n'
            "        </intent>\n"
            "    </queries>\n    <application"
        )
        xml = xml.replace("<application", queries, 1)
    if "ACTION_SHOW_PERMISSIONS_RATIONALE" not in xml:
        rationale = (
            "<intent-filter>\n"
            '                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>\n'
            "            </intent-filter>\n"
            "            <intent-filter>"
        )
        xml = xml.replace("<intent-filter>", rationale, 1)
    if "VIEW_PERMISSION_USAGE" not in xml:
        alias = (
            '<activity-alias android:name="ViewPermissionUsageActivity" android:exported="true"\n'
            '            android:targetActivity=".MainActivity"\n'
            '            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">\n'
            "            <intent-filter>\n"
            '                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>\n'
            '                <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>\n'
            "            </intent-filter>\n"
            "        </activity-alias>\n    </application>"
        )
        xml = xml.replace("</application>", alias, 1)
    return xml


def gradle(txt: str) -> str:
    txt = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 26", txt)
    txt = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 26", txt)
    txt = re.sub(r"minSdk\s*=\s*\d+", "minSdk = 26", txt)
    return txt


SIGNING_IMPORTS = """import java.io.FileInputStream
import java.util.Properties

"""

SIGNING_PROPS = """val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {"""

SIGNING_BLOCK = """    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {"""


def gradle_signing(txt: str) -> str:
    """Firma fija: si existe android/key.properties (creado en GitHub Actions desde los secretos), el APK
    se firma siempre con la misma clave y las actualizaciones se instalan encima conservando los datos."""
    if "keystorePropertiesFile" in txt:
        return txt
    # En Kotlin DSL solo los imports pueden ir antes de plugins {}; las variables van antes de android {}.
    txt = SIGNING_IMPORTS + txt
    txt = re.sub(r"^android \{", SIGNING_PROPS, txt, count=1, flags=re.M)
    txt = txt.replace("    buildTypes {", SIGNING_BLOCK, 1)
    txt = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
                 'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")', txt)
    return txt


def main_activity(txt: str) -> str:
    txt = txt.replace("io.flutter.embedding.android.FlutterActivity", "io.flutter.embedding.android.FlutterFragmentActivity")
    txt = re.sub(r"\bFlutterActivity\(\)", "FlutterFragmentActivity()", txt)
    txt = re.sub(r"extends FlutterActivity\b", "extends FlutterFragmentActivity", txt)
    return txt


patch_file(ROOT / "android/app/src/main/AndroidManifest.xml", manifest)
for g in ["android/app/build.gradle.kts", "android/app/build.gradle"]:
    patch_file(ROOT / g, gradle)
patch_file(ROOT / "android/app/build.gradle.kts", gradle_signing)
for ma in (ROOT / "android/app/src/main").rglob("MainActivity.*"):
    patch_file(ma, main_activity)

# ---------------- iOS ----------------
IOS_KEYS = {
    "CFBundleDisplayName": "Coachless",
    "NSHealthShareUsageDescription": "Coachless lee tus pasos, pulso, calorías, sueño y entrenamientos para ajustar tu rutina.",
    "NSHealthUpdateUsageDescription": "Coachless registra tus entrenamientos completados en Salud.",
    "NSLocationWhenInUseUsageDescription": "Coachless usa tu ubicación para mostrar supermercados cercanos y el costo de tus recetas.",
}


def info_plist(xml: str) -> str:
    for k, v in IOS_KEYS.items():
        if f"<key>{k}</key>" in xml:
            xml = re.sub(rf"(<key>{k}</key>\s*<string>)[^<]*(</string>)", rf"\g<1>{v}\g<2>", xml)
        else:
            xml = xml.replace("<dict>", f"<dict>\n\t<key>{k}</key>\n\t<string>{v}</string>", 1)
    return xml


def pbxproj(txt: str) -> str:
    return re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 14.0;", txt)


def podfile(txt: str) -> str:
    txt = re.sub(r"^#?\s*platform :ios, '[\d.]+'", "platform :ios, '14.0'", txt, flags=re.M)
    return txt


patch_file(ROOT / "ios/Runner/Info.plist", info_plist)
patch_file(ROOT / "ios/Runner.xcodeproj/project.pbxproj", pbxproj)
pf = ROOT / "ios/Podfile"
if not (ROOT / "ios").exists():
    pass
elif pf.exists():
    patch_file(pf, podfile)
else:
    pf.write_text(
        "platform :ios, '14.0'\n"
        "ENV['COCOAPODS_DISABLE_STATS'] = 'true'\n"
        "project 'Runner', {'Debug' => :debug, 'Profile' => :release, 'Release' => :release}\n"
        "def flutter_root\n"
        "  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)\n"
        "  unless File.exist?(generated_xcode_build_settings_path)\n"
        "    raise \"#{generated_xcode_build_settings_path} must exist. Run flutter pub get first\"\n"
        "  end\n"
        "  File.foreach(generated_xcode_build_settings_path) do |line|\n"
        "    matches = line.match(/FLUTTER_ROOT\\=(.*)/)\n"
        "    return matches[1].strip if matches\n"
        "  end\n"
        "  raise \"FLUTTER_ROOT not found\"\n"
        "end\n"
        "require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)\n"
        "flutter_ios_podfile_setup\n"
        "target 'Runner' do\n"
        "  use_frameworks!\n"
        "  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))\n"
        "end\n"
        "post_install do |installer|\n"
        "  installer.pods_project.targets.each do |target|\n"
        "    flutter_additional_ios_build_settings(target)\n"
        "    target.build_configurations.each do |config|\n"
        "      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'\n"
        "    end\n"
        "  end\n"
        "end\n",
        encoding="utf-8",
    )
    print(f"creado: {pf}")

# ---------------- Web ----------------
import json as _json


def web_index(html: str) -> str:
    html = re.sub(r"<title>.*?</title>", "<title>Coachless</title>", html, flags=re.S)
    html = re.sub(r'<meta name="description" content="[^"]*">', '<meta name="description" content="Coachless - tu propio entrenador: rutinas, dieta sana y seguimiento con tu reloj.">', html)
    html = re.sub(r'<meta name="apple-mobile-web-app-title" content="[^"]*">', '<meta name="apple-mobile-web-app-title" content="Coachless">', html)
    html = html.replace('content="black"', 'content="black-translucent"')
    extra = ('<meta name="theme-color" content="#080D19">\n'
             '  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
             '  <style>html,body{background:#080D19;margin:0}</style>\n')
    if 'name="theme-color"' not in html:
        html = html.replace("</head>", "  " + extra + "</head>", 1)
    if 'apple-mobile-web-app-capable' not in html:
        html = html.replace("</head>", '  <meta name="apple-mobile-web-app-capable" content="yes">\n</head>', 1)
    return html


def web_manifest(txt: str) -> str:
    m = _json.loads(txt)
    m.update({"name": "Coachless", "short_name": "Coachless", "description": "Tu propio entrenador: rutinas, dieta sana y seguimiento con tu reloj.",
              "background_color": "#080D19", "theme_color": "#080D19", "display": "standalone", "orientation": "portrait", "start_url": "."})
    return _json.dumps(m, ensure_ascii=False, indent=2)


patch_file(ROOT / "web/index.html", web_index)
patch_file(ROOT / "web/manifest.json", web_manifest)

print("Plataformas listas para Coachless.")
