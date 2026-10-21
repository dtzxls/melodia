# Melodia — Local Music Player (YouTube backend)

Um player de música estilo "Spotify" que roda **100% local** no seu iPhone:
- Busca no YouTube (via API interna, sem chave)
- Conta local (usuário/senha salvos no aparelho)
- Playlists locais, histórico local
- **Download de áudio (m4a) para ouvir offline**
- Background playback + controles na lock screen
- Sem servidores, sem telemetria, sem anúncios

> ⚠️ **Aviso de ToS**: este app usa endpoints internos do YouTube (Innertube) para busca e streaming.
> O YouTube proíbe oficialmente o uso automatizado sem API Key.
> Use por sua conta e risco — apenas para uso pessoal.

---

## Estrutura

```
Melodia/
├── App/                    # Código Swift (SwiftUI, iOS 16+)
│   ├── MelodiaApp.swift
│   ├── AppModel.swift      # Estado global, persistência, download
│   ├── Models.swift
│   ├── Persistence.swift   # Arquivos JSON em Application Support
│   ├── YouTubeAPI.swift    # Busca + resolução de stream (Innertube)
│   ├── PlayerController.swift # AVPlayer + MediaPlayer remote
│   ├── Theme.swift
│   ├── TrackRow.swift
│   ├── AuthView.swift
│   ├── HomeView.swift
│   ├── SearchView.swift
│   ├── LibraryView.swift
│   ├── PlaylistDetailView.swift
│   ├── NowPlayingView.swift
│   ├── MiniPlayerView.swift
│   └── RootView.swift
├── Info.plist
├── Melodia.xcodeproj/
│   └── project.pbxproj     # Projeto Xcode 16 (synchronized file groups)
├── project.yml             # Fallback: `xcodegen generate`
└── .github/workflows/build-ipa.yml
```

---

## Como gerar o `.ipa`

### Opção A — Xcode no Mac (recomendado)

1. Abra `Melodia.xcodeproj` no **Xcode 16+**
2. Selecione o target **Melodia** → **Signing & Capabilities** → **Team: (seu Apple ID)**
3. `Product → Archive`
4. No Organizer: `Distribute App → Development → Next → Export`
5. Salve o `.ipa` → instale no iPhone via **Sideloadly** / **AltStore** / **Xcode → Devices**

> **Conta Apple gratuita** funciona (certificado válido por 7 dias; AltStore/Sideloadly renovam automaticamente).
> Para instalação permanente sem Mac: **TrollStore** (iOS ≤ 17.0 / certas versões).

---

### Opção B — Sem Mac (GitHub Actions + Sideloadly no Windows)

1. Crie um repositório no GitHub e suba esta pasta inteira
2. O workflow **`.github/workflows/build-ipa.yml`** roda sozinho a cada push
3. Na aba **Actions → Build IPA → artifacts**, baixe `Melodia-unsigned.ipa`
4. No Windows, abra **Sideloadly** (instale o **Apple Devices** / iTunes antes)
   - Conecte o iPhone → ative **Modo Desenvolvedor** (Ajustes → Privacidade e Segurança)
   - Arraste o `.ipa` no Sideloadly → **Start** → insira seu Apple ID/senha
   - O app assinado será instalado no iPhone (válido 7 dias; Sideloadly renova)

> O IPA do Actions **não é assinado** — o Sideloadly assina na hora com seu Apple ID.

---

## Persistência (onde ficam os dados)

```
~/Library/Application Support/Melodia/
├── users.json
└── Users/<user-id>/
    ├── playlists.json
    ├── history.json
    ├── downloads.json
    └── Downloads/
        └── <videoId>.m4a
```

Tudo fica **no aparelho** — apague o app e os dados vão junto.

---

## Build manual (linha de comando)

```bash
# 1) Com XcodeGen (se preferir regenerar o .xcodeproj)
brew install xcodegen
xcodegen generate

# 2) Build para dispositivo (precisa de team assinado)
xcodebuild -project Melodia.xcodeproj -scheme Melodia -configuration Release -sdk iphoneos build

# 3) Build sem assinatura (para Sideloadly assinar depois)
xcodebuild -project Melodia.xcodeproj -target Melodia -configuration Release -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build

# 4) Empacotar .ipa não assinado
mkdir -p Payload
cp -r build/Release-iphoneos/Melodia.app Payload/
zip -r Melodia-unsigned.ipa Payload
```

---

## Requisitos

- **iOS 16.0+**
- **Xcode 16+** (ou XcodeGen + Xcode 15+)
- Swift 5.9+

---

## Limitações conhecidas (v1)

- Sem reordenação drag-and-drop nas playlists
- Sem crossfade / equalizador
- Sem busca por letra
- Downloads usam stream direto (URL expira em ~6 h; baixe de novo se der erro)
- YouTube pode bloquear IPs que abusam — use com moderação

---

## Licença

Código fornecido "como está", sem garantias. Use para estudo / uso pessoal.