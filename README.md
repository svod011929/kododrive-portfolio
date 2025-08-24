# 🚀 KodoDrive Portfolio - Автоматическая установка веб-сайта

<div align="center">

![KodoDrive](https://img.shields.io/badge/KodoDrive-Portfolio-blue?style=for-the-badge&logo=python&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.0-green?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

**Профессиональный сайт-портфолио для Python разработчика с админ-панелью**

[🌐 Демо](https://kododrive.ru) • [📖 Документация](#-установка) • [🐛 Баги](../../issues) • [💡 Идеи](../../discussions)

</div>

---

## 📋 Описание

**KodoDrive Portfolio** - это современный, адаптивный веб-сайт портфолио для Python разработчиков, специализирующихся на создании Telegram-ботов. Включает полноценную систему управления контентом (CMS) и скрипт автоматической установки.

### ✨ Особенности

- 🎨 **Современный дизайн** - темная тема с градиентами и анимациями
- 📱 **Полностью адаптивный** - отлично работает на всех устройствах
- ⚡ **Быстрая загрузка** - оптимизированные ресурсы и кэширование
- 🛡️ **Безопасность** - SSL сертификат, firewall, автоматические бэкапы
- 🔧 **Админ-панель** - управление контентом без знания кода
- 🚀 **Автоустановка** - развертывание одной командой

## 🖼️ Скриншоты

<details>
<summary>📸 Посмотреть скриншоты</summary>

### Главная страница
![Главная страница](https://via.placeholder.com/800x400/0f0f23/6366f1?text=Hero+Section)

### Секция "О себе"
![О себе](https://via.placeholder.com/800x400/1a1a2e/8b5cf6?text=About+Section)

### Портфолио
![Портфолио](https://via.placeholder.com/800x400/0f0f23/06b6d4?text=Portfolio+Section)

### Админ-панель
![Админ панель](https://via.placeholder.com/800x400/f8f9fa/2c3e50?text=Admin+Panel)

</details>

## 🛠️ Технологии

### Backend
- **Python 3.8+** - основной язык
- **Flask** - веб-фреймворк
- **SQLAlchemy** - ORM для работы с БД
- **PostgreSQL** - основная база данных
- **Gunicorn** - WSGI сервер

### Frontend
- **HTML5** - разметка
- **CSS3** - стилизация с анимациями
- **JavaScript (ES6+)** - интерактивность
- **Bootstrap 5** - UI компоненты для админки
- **FontAwesome** - иконки

### Инфраструктура
- **Nginx** - веб-сервер и reverse proxy
- **Let's Encrypt** - SSL сертификаты
- **Ubuntu 22.04** - операционная система
- **Systemd** - управление сервисами

## 📁 Структура проекта

```
kododrive-portfolio/
├── 🐍 app.py                      # Основное Flask приложение
├── ⚙️ config.py                   # Конфигурация
├── 🚀 wsgi.py                     # WSGI точка входа
├── 📦 requirements.txt            # Python зависимости
├── 🔒 .env                        # Переменные окружения
├── 📊 migrations/                 # Миграции базы данных
├── 🎨 static/                     # Статические файлы
│   ├── css/style.css             # Основные стили
│   ├── js/script.js              # JavaScript
│   └── uploads/                  # Загружаемые файлы
├── 📄 templates/                  # HTML шаблоны
│   ├── index.html                # Главная страница
│   └── admin/                    # Админ-панель
│       ├── layout.html           # Базовый шаблон
│       ├── dashboard.html        # Dashboard
│       ├── portfolio.html        # Управление проектами
│       └── settings.html         # Настройки
├── 🔧 nginx/                      # Конфигурации Nginx
├── ⚙️ systemd/                    # Systemd сервисы
└── 📜 scripts/                    # Вспомогательные скрипты
    ├── backup.sh                 # Бэкап данных
    └── update.sh                 # Обновление
```

## 🚀 Установка

### Автоматическая установка (рекомендуется)

1. **Подключитесь к серверу Ubuntu 22.04:**
```bash
ssh root@your_server_ip
```

2. **Скачайте и запустите скрипт установки:**
```bash
wget https://raw.githubusercontent.com/yourusername/kododrive-portfolio/main/install_web.sh
chmod +x install_web.sh
sudo bash install_web.sh
```

3. **Следуйте инструкциям установщика:**
   - Введите IP адрес сервера
   - Укажите домен (например: kododrive.ru)
   - Введите email для SSL сертификата
   - Создайте пароли для БД и администратора

4. **Дождитесь завершения (10-15 минут)**

### ✅ Что делает скрипт автоматически:

<details>
<summary>🔧 Подробный список операций</summary>

#### Системная подготовка:
- ✅ Обновление Ubuntu 22.04
- ✅ Установка Python 3, PostgreSQL, Nginx
- ✅ Создание пользователя `kododrive`
- ✅ Настройка firewall (UFW)

#### База данных:
- ✅ Создание PostgreSQL базы данных
- ✅ Настройка пользователя БД
- ✅ Инициализация таблиц
- ✅ Добавление начальных данных

#### Веб-приложение:
- ✅ Создание виртуального окружения Python
- ✅ Установка всех зависимостей
- ✅ Настройка Flask приложения
- ✅ Создание всех файлов проекта
- ✅ Настройка Gunicorn сервера

#### Веб-сервер:
- ✅ Конфигурация Nginx
- ✅ Настройка SSL (Let's Encrypt)
- ✅ Оптимизация производительности
- ✅ Настройка кэширования

#### Безопасность:
- ✅ SSL сертификаты
- ✅ Настройка firewall
- ✅ Безопасные заголовки HTTP
- ✅ Автоматические бэкапы

</details>

## 🎯 Быстрый старт

После успешной установки:

1. **Откройте сайт в браузере:**
   ```
   https://yourdomain.com
   ```

2. **Войдите в админ-панель:**
   ```
   https://yourdomain.com/admin/login
   Логин: admin
   Пароль: [тот что указали при установке]
   ```

3. **Настройте контент:**
   - Обновите информацию о себе
   - Добавьте свои проекты
   - Настройте контактные данные
   - Загрузите свои изображения

## 🔧 Управление сайтом

### Полезные команды:

```bash
# Перезапуск приложения
sudo systemctl restart kododrive

# Просмотр логов
sudo journalctl -u kododrive -f

# Статус сервисов
sudo systemctl status kododrive nginx postgresql

# Обновление приложения
/home/kododrive/kododrive-portfolio/scripts/update.sh

# Создание бэкапа
/home/kododrive/kododrive-portfolio/scripts/backup.sh

# Просмотр конфигурации Nginx
sudo nano /etc/nginx/sites-available/yourdomain.com
```

### Структура админ-панели:

- 📊 **Dashboard** - общая статистика
- ⚙️ **Настройки сайта** - заголовки, описания, контакты
- 💼 **Портфолио** - управление проектами
- 🛠️ **Услуги** - редактирование предлагаемых услуг
- 📈 **Навыки** - управление навыками с процентами
- 📊 **Статистика** - числовые показатели для главной страницы

## 🎨 Кастомизация

### Изменение дизайна:

1. **CSS стили:**
   ```bash
   nano /home/kododrive/kododrive-portfolio/static/css/style.css
   ```

2. **Цветовая схема (CSS переменные):**
   ```css
   :root {
       --primary-color: #6366f1;    /* Основной цвет */
       --secondary-color: #8b5cf6;  /* Вторичный цвет */
       --accent-color: #06b6d4;     /* Акцентный цвет */
       --bg-color: #0f0f23;         /* Фон */
       --text-color: #ffffff;       /* Текст */
   }
   ```

3. **Добавление новых секций:**
   - Отредактируйте `templates/index.html`
   - Добавьте стили в `static/css/style.css`
   - При необходимости обновите модели в `app.py`

### Расширение функционала:

<details>
<summary>💡 Идеи для развития</summary>

- 📧 **Отправка email** через форму обратной связи
- 🌐 **Мультиязычность** (русский/английский)
- 📝 **Блог** для статей и туториалов
- 📊 **Аналитика** Google Analytics / Яндекс.Метрика
- 🔍 **SEO оптимизация** мета-теги, sitemap.xml
- 📱 **PWA** для мобильных устройств
- 🎥 **Галерея** с видео проектов
- 💬 **Чат-бот** для консультаций
- 🔗 **API** для интеграции с внешними сервисами
- 📈 **Метрики** производительности

</details>

## 🐛 Решение проблем

### Частые проблемы:

<details>
<summary>❗ Сайт не открывается</summary>

```bash
# Проверьте статус сервисов
sudo systemctl status kododrive nginx

# Проверьте логи
sudo journalctl -u kododrive -f
sudo tail -f /var/log/nginx/error.log

# Перезапустите сервисы
sudo systemctl restart kododrive nginx
```

</details>

<details>
<summary>🔒 Проблемы с SSL</summary>

```bash
# Проверьте сертификат
sudo certbot certificates

# Обновите сертификат
sudo certbot renew

# Перезапустите Nginx
sudo systemctl reload nginx
```

</details>

<details>
<summary>🗄️ Проблемы с базой данных</summary>

```bash
# Проверьте статус PostgreSQL
sudo systemctl status postgresql

# Подключитесь к базе
sudo -u postgres psql kododrive_db

# Сделайте бэкап
/home/kododrive/kododrive-portfolio/scripts/backup.sh
```

</details>

<details>
<summary>🔧 Восстановление из бэкапа</summary>

```bash
# Найдите файл бэкапа
ls -la /home/kododrive/backups/

# Восстановите базу данных
sudo -u postgres psql -c "DROP DATABASE IF EXISTS kododrive_db;"
sudo -u postgres psql -c "CREATE DATABASE kododrive_db;"
sudo -u postgres psql kododrive_db < /home/kododrive/backups/db_backup_YYYYMMDD_HHMMSS.sql
```

</details>

## 📊 Производительность

### Оптимизации:

- ⚡ **Gzip сжатие** для текстовых файлов
- 🗄️ **Кэширование статики** на 1 год
- 🚀 **HTTP/2** поддержка
- 📦 **Минификация** CSS и JS (в production)
- 🖼️ **Lazy loading** изображений
- 🔄 **CDN готовность** для статических файлов

### Мониторинг:

```bash
# Использование ресурсов
htop

# Статистика Nginx
sudo nginx -T

# Логи доступа
sudo tail -f /var/log/nginx/access.log

# Размер базы данных
sudo -u postgres psql -c "\l+ kododrive_db"
```

## 🔐 Безопасность

### Реализованные меры:

- 🛡️ **SSL/TLS шифрование** (A+ rating)
- 🔥 **Firewall** настройка
- 🚫 **Security headers** (XSS, CSRF защита)
- 🔒 **Пароли хешируются** (Werkzeug)
- 📝 **Валидация входных данных**
- 🚨 **Автоматические бэкапы**
- 🔄 **Автообновление SSL**

### Рекомендации:

- Регулярно обновляйте систему: `sudo apt update && sudo apt upgrade`
- Меняйте пароли каждые 3-6 месяцев
- Мониторьте логи на подозрительную активность
- Используйте strong пароли (12+ символов)

## 📈 SEO оптимизация

### Встроенные возможности:

- 📋 **Semantic HTML5** разметка
- 🏷️ **Meta теги** для каждой страницы
- 🖼️ **Alt атрибуты** для изображений
- 📱 **Mobile-first** подход
- ⚡ **Page Speed** оптимизация
- 🗺️ **Structured data** готовность

### Для улучшения SEO:

1. **Добавьте sitemap.xml**
2. **Настройте Google Analytics**
3. **Зарегистрируйте в Google Search Console**
4. **Добавьте Open Graph теги**
5. **Создайте robots.txt**

## 🤝 Вклад в проект

Мы приветствуем ваш вклад! Вот как можно помочь:

1. 🍴 **Fork** репозитория
2. 🌟 **Создайте** ветку для новой функции: `git checkout -b feature/AmazingFeature`
3. ✅ **Commit** изменения: `git commit -m 'Add some AmazingFeature'`
4. 📤 **Push** в ветку: `git push origin feature/AmazingFeature`
5. 🔄 **Откройте** Pull Request

### Типы вкладов:

- 🐛 **Исправление багов**
- ✨ **Новые функции**
- 📚 **Улучшение документации**
- 🎨 **UI/UX улучшения**
- ⚡ **Оптимизация производительности**
- 🔒 **Улучшение безопасности**

## 📝 Changelog

### v1.0.0 (2024-12-XX)
- ✨ Первый релиз
- 🎨 Современный адаптивный дизайн
- 🔧 Полноценная админ-панель
- 🚀 Скрипт автоматической установки
- 🛡️ SSL и безопасность
- 📱 Мобильная адаптация

## 📄 Лицензия

Этот проект лицензирован под MIT License - подробности в файле [LICENSE](LICENSE).

## 👤 Автор

**KodoDrive**
- 🌐 Website: [kododrive.ru](https://kododrive.ru)
- 💬 Telegram: [@kodoDrive](https://t.me/kodoDrive)
- 💻 GitHub: [@kododrive](https://github.com/svod011929)

## 🙏 Благодарности

- [Flask](https://flask.palletsprojects.com/) - за отличный веб-фреймворк
- [Bootstrap](https://getbootstrap.com/) - за UI компоненты
- [FontAwesome](https://fontawesome.com/) - за иконки
- [Let's Encrypt](https://letsencrypt.org/) - за бесплатные SSL сертификаты

---

<div align="center">

**⭐ Если проект оказался полезным - поставьте звездочку! ⭐**

[![GitHub stars](https://img.shields.io/github/stars/svod01192/portfolio?style=social)](https://github.com/kododrive/portfolio/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/svod011929/portfolio?style=social)](https://github.com/kododrive/portfolio/network/members)
[![GitHub watchers](https://img.shields.io/github/watchers/svod011929/portfolio?style=social)](https://github.com/kododrive/portfolio/watchers)

**Сделано с ❤️ для Python разработчиков**

</div>
