# Services+

Services+ is an extended services app for **LB Phone**.

It allows players to quickly find companies, call them, send messages or create service requests. Employees get their own company area to manage calls, requests, messages and availability.

## Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/4bf617c1-7fd8-4510-b083-07608a68be7e" width="180" alt="Services+ Screenshot 1" />
  &nbsp;
  <img src="https://github.com/user-attachments/assets/91c767eb-3c46-450f-b22f-94ae13acefac" width="180" alt="Services+ Screenshot 2" />
  &nbsp;
  <img src="https://github.com/user-attachments/assets/f3bd80bf-8b63-4a0f-90ae-da0909dff887" width="180" alt="Services+ Screenshot 3" />
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/59b17e2a-9983-45c5-9453-180e988736e1" width="180" alt="Services+ Screenshot 4" />
  &nbsp;
  <img src="https://github.com/user-attachments/assets/084532fc-3700-477d-93b3-deceeeadc784" width="180" alt="Services+ Screenshot 5" />
</p>





## Main Features

### For Players

- Browse available companies
- Search and filter companies
- See if a company is currently available
- Call companies directly
- Send messages to companies
- Create service requests
- View previous calls, messages and requests

### For Employees

- Go on or off duty
- Set status to Available, Busy or Pause
- Join or leave hotlines
- Receive and accept service requests
- Get an automatic waypoint to accepted requests
- Manage company messages
- View company call history
- See other employees and their current status

### For Companies

- Multiple phone numbers
- Different call routing modes
- Different request routing modes
- Separate mailboxes
- Custom request types
- Hotline / dispatcher system
- Company settings for bosses

### For Admins

- Create and manage companies
- Create categories
- Add and manage phone numbers
- Create request types
- Configure company permissions and features

## Supported Frameworks

- ESX
- QBCore
- Qbox
- Standalone

Framework detection can be automatic.

## Requirements

- LB Phone
- oxmysql
- MySQL / MariaDB

## Installation

### 1. Add the resource

Place the `services-plus` folder inside your FiveM resources directory.

### 2. Import the database

Import:

```text
sql/install.sql
```

### 3. Build the UI

Inside the `ui` folder run:

```bash
npm install
npm run build
```

### 4. Start Services+

Add this to your `server.cfg`:

```cfg
ensure oxmysql
ensure lb-phone
ensure services-plus
```

## Configuration

The main configuration file is:

```text
shared/config.lua
```

Most important settings such as framework, permissions and default routing can be changed there.

## Admin Access

Services+ uses this ACE permission:

```text
servicesplus.admin
```

Example:

```cfg
add_ace identifier.license:YOUR_LICENSE servicesplus.admin allow
```

## Important

Services+ runs as its own FiveM resource.

No LB Phone core files need to be modified.
