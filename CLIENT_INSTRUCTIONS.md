# Instructions pour Installer PromptTracker avec Webpacker

Bonjour ! Voici comment installer PromptTracker dans votre application Rails qui utilise Webpacker.

## 🚀 Option 1 : Avec Importmap (RECOMMANDÉ - 2 minutes)

C'est la solution la plus simple et la plus fiable :

### 1. Mettez à jour votre Gemfile

```ruby
gem "prompt_tracker", git: "https://github.com/DavidGeismarLtd/PromptTracker.git"
```

### 2. Installez les dépendances

```bash
bundle install
bundle add importmap-rails
bin/rails importmap:install
```

### 3. Montez l'engine et lancez les migrations

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount PromptTracker::Engine, at: "/prompt_tracker"
  # ... vos autres routes
end
```

```bash
bin/rails prompt_tracker:install:migrations
bin/rails db:migrate
```

### 4. Démarrez votre serveur

```bash
bin/rails server
```

Visitez : http://localhost:3000/prompt_tracker

**✅ C'est tout !** Votre app continue d'utiliser Webpacker, et PromptTracker utilise importmap pour ses propres assets. Aucun conflit !

---

## ⚙️ Option 2 : Webpacker Pur (AVANCÉ - 10 minutes)

Si vous ne voulez vraiment pas installer importmap, voici la procédure :

### 1. Mettez à jour votre Gemfile

```ruby
gem "prompt_tracker", git: "https://github.com/DavidGeismarLtd/PromptTracker.git"
```

```bash
bundle install
```

### 2. Installez les dépendances JavaScript

```bash
yarn add @hotwired/turbo-rails @hotwired/stimulus @hotwired/stimulus-loading
```

### 3. Créez un symlink vers les assets de l'engine

```bash
cd app/javascript
ln -s $(bundle show prompt_tracker)/app/javascript/prompt_tracker prompt_tracker
cd ../..
```

### 4. Importez PromptTracker dans votre pack

**Fichier : `app/javascript/packs/application.js`**

```javascript
// Vos imports existants
import "@hotwired/turbo-rails"
import "controllers"

// Ajoutez cette ligne
import "prompt_tracker/application"

// Vos autres imports...
```

### 5. Montez l'engine et lancez les migrations

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount PromptTracker::Engine, at: "/prompt_tracker"
  # ... vos autres routes
end
```

```bash
bin/rails prompt_tracker:install:migrations
bin/rails db:migrate
```

### 6. Recompilez les assets

```bash
bin/webpack
```

### 7. Démarrez votre serveur

```bash
bin/rails server
```

### ⚠️ Important : Après chaque `bundle update prompt_tracker`

Vous devrez recréer le symlink :

```bash
cd app/javascript
rm prompt_tracker
ln -s $(bundle show prompt_tracker)/app/javascript/prompt_tracker prompt_tracker
bin/webpack
```

**Script d'automatisation** : Créez `bin/update_prompt_tracker` :

```bash
#!/bin/bash
set -e

echo "Updating PromptTracker..."
bundle update prompt_tracker

echo "Recreating symlink..."
cd app/javascript
rm -f prompt_tracker
ln -s $(bundle show prompt_tracker)/app/javascript/prompt_tracker prompt_tracker
cd ../..

echo "Running migrations..."
bin/rails prompt_tracker:install:migrations
bin/rails db:migrate

echo "Recompiling assets..."
bin/webpack

echo "✅ PromptTracker updated successfully!"
```

```bash
chmod +x bin/update_prompt_tracker
```

---

## 🤔 Quelle Option Choisir ?

| Critère | Option 1 (Importmap) | Option 2 (Webpacker Pur) |
|---------|---------------------|--------------------------|
| **Facilité** | ✅ Très simple | ⚠️ Configuration manuelle |
| **Maintenance** | ✅ `bundle update` suffit | ❌ Symlink à recréer à chaque update |
| **Compilation** | ✅ Instantanée | ⚠️ Plus lente (Webpacker) |
| **Conflits** | ✅ Aucun | ⚠️ Possibles avec dépendances JS |
| **Temps d'installation** | ✅ 2 minutes | ⚠️ 10 minutes |

**Notre recommandation** : **Option 1** (avec importmap)

Même si votre app utilise Webpacker, installer importmap pour PromptTracker est la meilleure solution :
- Pas de configuration complexe
- Pas de maintenance
- Isolation complète
- Mises à jour faciles

---

## 📚 Documentation Complète

- **[Quick Fix (30 secondes)](docs/QUICK_FIX_WEBPACKER.md)** - Fix rapide si vous avez une erreur
- **[Webpacker Setup avec Importmap](docs/webpacker_setup.md)** - Guide détaillé Option 1
- **[Pure Webpacker Setup](docs/client_webpacker_setup.md)** - Guide détaillé Option 2
- **[Exemple Complet](docs/examples/webpacker_rails_app_setup.md)** - Exemple pas à pas
- **[Troubleshooting](docs/troubleshooting/webpacker_importmap_conflict.md)** - Dépannage

---

## 🆘 Besoin d'Aide ?

Si vous rencontrez des problèmes :

1. Vérifiez la [documentation de troubleshooting](docs/troubleshooting/webpacker_importmap_conflict.md)
2. Ouvrez une issue sur GitHub avec :
   - Votre version de Rails
   - Votre version de Webpacker/Shakapacker
   - Le message d'erreur complet
   - Les étapes pour reproduire

---

**TL;DR** : Utilisez l'Option 1 (avec importmap), c'est beaucoup plus simple ! 🚀

