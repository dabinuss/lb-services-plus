# Services+

Services+ is an extended services app for **LB Phone**.

It allows players to quickly find companies, call them, send messages or create service requests. Employees get their own company area to manage calls, requests, messages and availability.

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
