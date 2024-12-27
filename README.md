# Script d'installation d'Odoo 18 sur Ubuntu 24.04

Ce script permet d'installer Odoo 18 sur un serveur Ubuntu 24.04 avec toutes les dépendances nécessaires, PostgreSQL, Nginx, et un environnement virtuel Python.

## Fonctionnalités

- Installation d'Odoo 18
- Configuration de PostgreSQL
- Création d'un environnement virtuel Python
- Configuration de Nginx comme proxy inverse
- Option pour activer SSL avec Certbot
- Gestion via un service systemd

## Prérequis

- Un serveur Ubuntu 24.04
- Accès root ou un utilisateur avec des privilèges sudo
- Un nom de domaine configuré (si vous souhaitez activer SSL)

## Installation

1. Clonez ce dépôt sur votre serveur :
   ```bash
   git clone https://github.com/Mahjoub-sami/odoo-install-script.git
   cd odoo-install-script
