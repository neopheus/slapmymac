import Foundation

enum L10nFR {
    static let strings: [String: String] = [
        // App
        "app.name": "SlapMyMac",
        "app.tagline": "Tape ton Mac, il te r\u{00E9}pond.",
        "app.version": "v1.6 \u{2014} macOS 14+ \u{2014} Apple Silicon",

        // Menu bar header
        "menubar.listening": "En \u{00E9}coute...",
        "menubar.paused": "En pause",
        "menubar.slaps": "claques",
        "menubar.lifetime": "Total : %d",
        "menubar.detectors": "(%d d\u{00E9}tecteurs)",

        // Lid events
        "lid.opened": "OUVERT",
        "lid.closed": "FERM\u{00C9}",
        "lid.slammed": "CLAQU\u{00C9}",
        "lid.creak": "GRINCEMENT",
        "lid.angle": "Angle du capot",

        // Voice pack card
        "voicepack.title": "Pack de sons",
        "voicepack.clips": "%d sons",

        // Sensitivity card
        "sensitivity.title": "Sensibilit\u{00E9}",
        "sensitivity.cooldown": "D\u{00E9}lai : %@",
        "sensitivity.volumeScaling": "Volume dynamique",

        // Debug card
        "debug.accelerometer": "ACC\u{00C9}L\u{00C9}ROM\u{00C8}TRE",

        // Impact badges
        "impact.major": "MAJEUR",
        "impact.medium": "MOYEN",
        "impact.micro": "MICRO",
        "impact.vibration": "VIBRATION",

        // Mute timer
        "mute.title": "Minuteur silence",
        "mute.for": "Silence %d min",
        "mute.remaining": "Muet \u{2014} %@ restant",
        "mute.cancel": "Annuler",
        "mute.5min": "5 min",
        "mute.15min": "15 min",
        "mute.30min": "30 min",
        "mute.60min": "1 heure",

        // Sparkline
        "sparkline.title": "IMPACTS R\u{00C9}CENTS",
        "sparkline.empty": "Aucun impact",

        // Preferences tabs
        "tab.general": "G\u{00E9}n\u{00E9}ral",
        "tab.sounds": "Sons",
        "tab.sensors": "Capteurs",
        "tab.stats": "Stats",
        "tab.leaderboard": "Classement",
        "tab.profiles": "Profils",
        "tab.roadmap": "Feuille de route",
        "tab.about": "\u{00C0} propos",

        // General tab - Startup
        "general.startup": "D\u{00E9}marrage",
        "general.launchAtLogin": "Lancer au d\u{00E9}marrage",

        // General tab - Language
        "general.language": "Langue",
        "general.language.label": "Langue de l\u{2019}app",
        "general.language.restart": "Red\u{00E9}marrez l\u{2019}app pour appliquer le changement",

        // General tab - Detection
        "general.detection": "D\u{00E9}tection",
        "general.sensitivity": "Sensibilit\u{00E9}",
        "general.sensitivity.earthquake": "D\u{00E9}tecteur sismique",
        "general.sensitivity.feather": "Toucher plume",
        "general.sensitivity.light": "Tape l\u{00E9}g\u{00E8}re",
        "general.sensitivity.normal": "Claque normale",
        "general.sensitivity.strong": "Frappe forte",
        "general.sensitivity.running": "Faut prendre de l\u{2019}\u{00E9}lan",
        "general.cooldown": "D\u{00E9}lai",
        "general.cooldown.desc": "D\u{00E9}lai minimum entre les effets sonores",

        // General tab - Audio
        "general.audio": "Audio",
        "general.masterVolume": "Volume principal",
        "general.volumeScaling": "Ajuster le volume selon la force",
        "general.volumeScaling.desc": "Les claques plus fortes jouent plus fort",
        "general.respectFocus": "Respecter le mode Concentration",
        "general.respectFocus.desc": "Couper le son quand le mode Concentration est actif",
        "general.startupSound": "Son au d\u{00E9}marrage/arr\u{00EA}t",
        "general.startupSound.desc": "Retour audio au basculement de la d\u{00E9}tection",

        // General tab - Lid
        "general.lidSounds": "Sons du capot",
        "general.lidContinuous": "Audio continu du capot (grincement/th\u{00E9}r\u{00E9}mine)",
        "general.lidEvents": "Sons d\u{2019}\u{00E9}v\u{00E9}nements du capot (ouverture/fermeture/claquage)",
        "general.lidMode": "Mode",

        // General tab - Lid Performance
        "general.lidPerformance": "Performance du capot",
        "general.pollRate": "Fr\u{00E9}quence de lecture",
        "general.pollRate.low": "15 Hz (l\u{00E9}ger)",
        "general.pollRate.high": "120 Hz (rapide)",
        "general.angleSmoothing": "Lissage de l\u{2019}angle",
        "general.angleSmoothing.desc": "Constante de temps \u{2014} plus bas = plus r\u{00E9}actif, plus bruit\u{00E9}",
        "general.eventCooldown": "D\u{00E9}lai entre \u{00E9}v\u{00E9}nements",
        "general.eventCooldown.desc": "D\u{00E9}lai minimum entre les \u{00E9}v\u{00E9}nements ouverture/fermeture/claquage",
        "general.lidEngine": "Audio du capot : AVAudioEngine avec ~6ms de latence",

        // General tab - Performance
        "general.performance": "Performance",
        "general.sampleRate": "Fr\u{00E9}quence d\u{2019}\u{00E9}chantillonnage",
        "general.sampleRate.fast": "400 Hz (rapide)",
        "general.sampleRate.light": "100 Hz (l\u{00E9}ger)",
        "general.suppression": "Suppression post-impact",
        "general.suppression.desc": "Bloque les re-d\u{00E9}clenchements des vibrations r\u{00E9}siduelles",
        "general.kurtosis": "\u{00C9}valuation Kurtosis",
        "general.kurtosis.every": "Chaque \u{00E9}chantillon",
        "general.kurtosis.everyN": "Tous les %d \u{00E9}chantillons",
        "general.kurtosis.desc": "Plus bas = d\u{00E9}tection plus rapide, un peu plus de CPU",
        "general.audioEngine": "Moteur audio : Tampons PCM pr\u{00E9}-d\u{00E9}cod\u{00E9}s (~2ms de latence)",

        // General tab - Menu Bar
        "general.menuBar": "Barre de menus",
        "general.showCount": "Afficher le compteur dans la barre de menus",
        "general.milestoneNotif": "Notifications de paliers",
        "general.milestoneNotif.desc": "Notifier \u{00E0} 10, 50, 100, 500, 1000 claques et nouveaux records",

        // General tab - MCP Server
        "general.mcpServer": "Serveur MCP",
        "general.mcpEnabled": "Activer le serveur MCP local",
        "general.mcpDesc": "Expose les donn\u{00E9}es sur http://localhost:7749 pour outils IA et scripts",

        // General tab - Hotkey
        "general.hotkey": "Raccourci global",
        "general.hotkeyToggle": "Basculer l\u{2019}\u{00E9}coute",
        "general.hotkeyDefault": "Cmd + Shift + S",
        "general.hotkeyDesc": "Fonctionne depuis n\u{2019}importe quelle app",

        // Sounds tab
        "sounds.voicePack": "Pack de sons",
        "sounds.activePack": "Pack actif",
        "sounds.clipsLoaded": "Sons charg\u{00E9}s",
        "sounds.testSound": "Tester un son",
        "sounds.customSounds": "Sons personnalis\u{00E9}s",
        "sounds.folderPath": "Chemin du dossier",
        "sounds.browse": "Parcourir...",
        "sounds.browseDesc": "S\u{00E9}lectionnez un dossier contenant des fichiers MP3",
        "sounds.included": "Packs de sons inclus",

        // Sensors tab
        "sensors.accelerometer": "Acc\u{00E9}l\u{00E9}rom\u{00E8}tre (BMI286)",
        "sensors.status": "\u{00C9}tat",
        "sensors.active": "Actif",
        "sensors.inactive": "Inactif",
        "sensors.reading": "Lecture",
        "sensors.error": "Erreur",
        "sensors.accelDesc": "Lit l\u{2019}IMU Bosch BMI286 via IOKit HID \u{00E0} ~%dHz",
        "sensors.lidSensor": "Capteur d\u{2019}angle du capot",
        "sensors.available": "Disponible",
        "sensors.yes": "Oui",
        "sensors.no": "Non",
        "sensors.angle": "Angle",
        "sensors.velocity": "Vitesse",
        "sensors.lidDesc": "Lit l\u{2019}angle du capot via IOKit HID \u{00E0} 30Hz",
        "sensors.algorithm": "Algorithme de d\u{00E9}tection",
        "sensors.algorithmDesc": "4 d\u{00E9}tecteurs parall\u{00E8}les : STA/LTA, CUSUM, Kurtosis, Peak/MAD",
        "sensors.classificationDesc": "Classification : Majeur (4+ d\u{00E9}tecteurs), Moyen (3+), Micro, Vibration",
        "sensors.permissionTitle": "Acc\u{00E8}s aux capteurs",
        "sensors.permissionDesc": "Si l\u{2019}acc\u{00E9}l\u{00E9}rom\u{00E8}tre affiche \u{2018}Inactif\u{2019} :\n1. Ouvrez R\u{00E9}glages Syst\u{00E8}me \u{2192} Confidentialit\u{00E9} et s\u{00E9}curit\u{00E9} \u{2192} Surveillance de l\u{2019}entr\u{00E9}e\n2. Ajoutez SlapMyMac et autorisez l\u{2019}acc\u{00E8}s\n3. Red\u{00E9}marrez l\u{2019}app",

        // Stats tab
        "stats.session": "Session",
        "stats.sessionSlaps": "Claques de la session",
        "stats.slapsPerMin": "Claques/minute",
        "stats.duration": "Dur\u{00E9}e",
        "stats.resetSession": "R\u{00E9}initialiser la session",
        "stats.allTime": "Historique",
        "stats.totalRecorded": "Total enregistr\u{00E9}",
        "stats.lifetimeCounter": "Compteur total",
        "stats.avgAmplitude": "Amplitude moy.",
        "stats.maxAmplitude": "Amplitude max.",
        "stats.majorImpacts": "Impacts majeurs",
        "stats.mediumImpacts": "Impacts moyens",
        "stats.favoriteMode": "Mode favori",
        "stats.recentHistory": "Historique r\u{00E9}cent",
        "stats.noSlaps": "Aucune claque enregistr\u{00E9}e. Allez, tape ton Mac !",
        "stats.exportCSV": "Exporter CSV...",
        "stats.exportFull": "Tout exporter (CSV + Classement)...",
        "stats.clearHistory": "Effacer l\u{2019}historique",

        // Leaderboard tab
        "leaderboard.topSlaps": "Top 10 des claques les plus fortes",
        "leaderboard.noSlaps": "Aucune claque enregistr\u{00E9}e. \u{00C0} toi de jouer !",
        "leaderboard.bestSessions": "Meilleures sessions",
        "leaderboard.noSessions": "Termine une session pour voir les records.",
        "leaderboard.slaps": "%d claques",
        "leaderboard.achievements": "Succ\u{00E8}s (%d/%d)",
        "leaderboard.copyClipboard": "Copier le classement",

        // Profiles tab
        "profiles.title": "Profils sonores",
        "profiles.desc": "Sauvegardez et rappelez des combinaisons de pack, sensibilit\u{00E9} et volume.",
        "profiles.noProfiles": "Aucun profil enregistr\u{00E9}.",
        "profiles.save": "Sauvegarder le profil actuel",
        "profiles.name": "Nom du profil",
        "profiles.load": "Charger",
        "profiles.delete": "Supprimer",
        "profiles.active": "Actif :",
        "profiles.pack": "Pack",
        "profiles.sensitivity": "Sensibilit\u{00E9}",
        "profiles.volume": "Volume",

        // Roadmap tab
        "roadmap.title": "Feuille de route",
        "roadmap.shipped": "Livr\u{00E9}",
        "roadmap.inProgress": "En cours",
        "roadmap.planned": "Pr\u{00E9}vu",
        "roadmap.v10.title": "Exp\u{00E9}rience de base",
        "roadmap.v10.desc": "D\u{00E9}tection de claques, 3 packs de sons (79 clips), app menu bar, capteur d\u{2019}angle du capot, contr\u{00F4}les de sensibilit\u{00E9}",
        "roadmap.v11.title": "Packs de sons personnalis\u{00E9}s",
        "roadmap.v11.desc": "Importez vos propres dossiers MP3. Votre voix, votre chat, votre patron \u{2014} tout est permis.",
        "roadmap.v12.title": "Sons d\u{2019}ouverture/fermeture du capot",
        "roadmap.v12.desc": "D\u{00E9}tecte l\u{2019}ouverture, la fermeture et le claquage du capot. Chaque \u{00E9}v\u{00E9}nement joue un son diff\u{00E9}rent.",
        "roadmap.v13.title": "Int\u{00E9}gration serveur MCP",
        "roadmap.v13.desc": "Serveur HTTP local sur le port 7749. Les outils IA et scripts peuvent lire les donn\u{00E9}es et d\u{00E9}clencher des sons.",
        "roadmap.v14.title": "Statistiques et historique",
        "roadmap.v14.desc": "Historique complet avec horodatage, amplitudes, s\u{00E9}v\u{00E9}rit\u{00E9}. Stats de session, compteur total, taux par minute.",
        "roadmap.v15.title": "Compteur dans la barre de menus",
        "roadmap.v15.desc": "Affiche le nombre de claques de la session dans la barre de menus, \u{00E0} c\u{00F4}t\u{00E9} de l\u{2019}ic\u{00F4}ne.",
        "roadmap.v16.title": "Localisation, profils et plus",
        "roadmap.v16.desc": "Localisation fran\u{00E7}aise, profils sonores, export/import des r\u{00E9}glages, minuteur silence, graphe d\u{2019}impacts, notifications de succ\u{00E8}s, th\u{00E8}me adaptatif.",
        "roadmap.v20.title": "Communaut\u{00E9} et cloud",
        "roadmap.v20.desc": "Partage communautaire de packs de sons, classements en ligne et mises \u{00E0} jour automatiques.",

        // About tab
        "about.lifetimeSlaps": "Total de claques :",
        "about.basedOn": "Bas\u{00E9} sur",
        "about.soundAttrib": "Attributions sonores",
        "about.soundCredits": "Pack Slap : SoundBible (Domaine Public) + Albert Wu (CC-BY 4.0)",
        "about.checkUpdates": "V\u{00E9}rifier les mises \u{00E0} jour...",
        "about.exportSettings": "Exporter les r\u{00E9}glages...",
        "about.importSettings": "Importer les r\u{00E9}glages...",
        "about.logs": "Voir les logs...",

        // Sound mode names
        "sound.pain": "Douleur",
        "sound.sexy": "Sexy",
        "sound.halo": "Halo",
        "sound.whip": "Fouet",
        "sound.cartoon": "Cartoon",
        "sound.kungfu": "Kung Fu",
        "sound.drum": "Batterie",
        "sound.cat": "Chat",
        "sound.glass": "Verre",
        "sound.eightbit": "8-Bit",
        "sound.thunder": "Tonnerre",
        "sound.wwe": "WWE",
        "sound.metal": "M\u{00E9}tal",
        "sound.slap": "Claque",
        "sound.mario": "Mario",
        "sound.lid": "Capot",
        "sound.custom": "Personnalis\u{00E9}",

        // Sound mode descriptions
        "sound.pain.desc": "10 r\u{00E9}actions de douleur",
        "sound.sexy.desc": "60 niveaux d\u{2019}intensit\u{00E9} croissante",
        "sound.halo.desc": "Sons de mort de Halo",
        "sound.whip.desc": "Coups de fouet et claquements",
        "sound.cartoon.desc": "Bonk, boing, splat, cloche",
        "sound.kungfu.desc": "Coups d\u{2019}arts martiaux et kiai",
        "sound.drum.desc": "Caisse claire, grosse caisse, crash",
        "sound.cat.desc": "Miaulements surpris et en col\u{00E8}re",
        "sound.glass.desc": "Craquements jusqu\u{2019}\u{00E0} l\u{2019}explosion",
        "sound.eightbit.desc": "Sons de jeux r\u{00E9}tro",
        "sound.thunder.desc": "Coups de tonnerre et grondements",
        "sound.wwe.desc": "Body slams et cris de foule",
        "sound.metal.desc": "Clang, gong, enclume",
        "sound.slap.desc": "Claques, gifles et fess\u{00E9}es",
        "sound.mario.desc": "Saut, pi\u{00E8}ce, \u{00E9}crasement, power-up",
        "sound.lid.desc": "Sons d\u{2019}ouverture/fermeture/claquage",
        "sound.custom.desc": "Vos propres fichiers MP3",

        // Achievement titles
        "achievement.firstSlap": "Premier contact",
        "achievement.slaps10": "C\u{2019}est parti",
        "achievement.slaps50": "\u{00C9}chauffement",
        "achievement.slaps100": "Club des 100",
        "achievement.slaps500": "Passionn\u{00E9} de claques",
        "achievement.slaps1000": "Ma\u{00EE}tre claqueur",
        "achievement.slaps5000": "L\u{00E9}gende de la claque",
        "achievement.amp01": "Toucher l\u{00E9}ger",
        "achievement.amp03": "Coup solide",
        "achievement.amp05": "S\u{00E9}isme",
        "achievement.amp08": "Destruction",
        "achievement.allMajor": "Temp\u{00EA}te parfaite",
        "achievement.rate10": "Tir rapide",
        "achievement.session30": "Marathon",
        "achievement.session100": "Endurance",

        // Achievement descriptions
        "achievement.firstSlap.desc": "Donne ta premi\u{00E8}re claque",
        "achievement.slaps10.desc": "10 claques au total",
        "achievement.slaps50.desc": "50 claques au total",
        "achievement.slaps100.desc": "100 claques au total",
        "achievement.slaps500.desc": "500 claques au total",
        "achievement.slaps1000.desc": "1 000 claques au total",
        "achievement.slaps5000.desc": "5 000 claques au total",
        "achievement.amp01.desc": "Atteindre 0.1g d\u{2019}amplitude",
        "achievement.amp03.desc": "Atteindre 0.3g d\u{2019}amplitude",
        "achievement.amp05.desc": "Atteindre 0.5g d\u{2019}amplitude",
        "achievement.amp08.desc": "Atteindre 0.8g d\u{2019}amplitude",
        "achievement.allMajor.desc": "D\u{00E9}clencher les 4 d\u{00E9}tecteurs",
        "achievement.rate10.desc": "10+ claques par minute",
        "achievement.session30.desc": "30+ claques en une session",
        "achievement.session100.desc": "100+ claques en une session",

        // Notifications
        "notif.firstSlap": "Premi\u{00E8}re claque !",
        "notif.firstSlap.body": "Ton Mac l\u{2019}a sentie.",
        "notif.milestone": "%d claques !",
        "notif.milestone.body": "Tu as atteint %d claques au total.",
        "notif.record": "Nouveau record !",
        "notif.record.body": "%.3fg \u{2014} ta claque la plus forte !",
        "notif.achievement": "Succ\u{00E8}s d\u{00E9}bloqu\u{00E9} !",
        "notif.achievement.body": "%@ \u{2014} %@",

        // Leaderboard share text
        "share.title": "Classement SlapMyMac",
        "share.lifetime": "Total de claques : %d",
        "share.hardest": "Claque la plus forte : %@",
        "share.achievements": "Succ\u{00E8}s : %d/%d",
        "share.top3": "Top 3 : %@",

        // Onboarding
        "onboarding.welcome.title": "Bienvenue dans SlapMyMac",
        "onboarding.welcome.body": "Ton MacBook d\u{00E9}tecte quand tu le tapes. On utilise l\u{2019}acc\u{00E9}l\u{00E9}rom\u{00E8}tre int\u{00E9}gr\u{00E9} pour d\u{00E9}tecter les impacts et jouer des sons. Vas-y, essaie !",
        "onboarding.sounds.title": "Choisis tes sons",
        "onboarding.sounds.body": "Choisis parmi 15 packs : Douleur, Sexy, Halo, Cartoon, Kung Fu, et plus encore. Tu peux aussi charger tes propres MP3.",
        "onboarding.sensitivity.title": "R\u{00E8}gle la sensibilit\u{00E9}",
        "onboarding.sensitivity.body": "Ajuste la force n\u{00E9}cessaire. Du \u{00AB} d\u{00E9}tecteur sismique \u{00BB} (sent tout) au \u{00AB} faut prendre de l\u{2019}\u{00E9}lan \u{00BB} (que les gros coups). Trouve ton r\u{00E9}glage dans la barre de menus.",
        "onboarding.menubar.title": "Vit dans ta barre de menus",
        "onboarding.menubar.body": "SlapMyMac tourne discr\u{00E8}tement dans ta barre de menus. Clique sur l\u{2019}ic\u{00F4}ne main pour voir ton compteur, changer de pack et ajuster les r\u{00E9}glages.",
        "onboarding.next": "Suivant",
        "onboarding.start": "C\u{2019}est parti !",
        "onboarding.skip": "Passer",

        // Settings export/import
        "settings.exported": "R\u{00E9}glages export\u{00E9}s avec succ\u{00E8}s",
        "settings.imported": "R\u{00E9}glages import\u{00E9}s avec succ\u{00E8}s",
        "settings.importError": "\u{00C9}chec de l\u{2019}importation des r\u{00E9}glages",
        "settings.exportDesc": "Exporter tous les r\u{00E9}glages, profils et donn\u{00E9}es du classement",
        "settings.importDesc": "Importer les r\u{00E9}glages depuis un fichier pr\u{00E9}c\u{00E9}demment export\u{00E9}",

        // Logger
        "log.title": "Logs de l\u{2019}application",
        "log.export": "Exporter les logs...",
        "log.clear": "Effacer les logs",
        "log.empty": "Aucune entr\u{00E9}e de log.",

        // Errors / Permission guidance
        "error.customEmpty": "Dossier personnalis\u{00E9} vide \u{2014} aucun fichier MP3 trouv\u{00E9}",
        "error.sensorAccess": "Acc\u{00E8}s aux capteurs refus\u{00E9}. V\u{00E9}rifiez R\u{00E9}glages Syst\u{00E8}me \u{2192} Confidentialit\u{00E9} et s\u{00E9}curit\u{00E9}.",
    ]
}
