# Lancache Installer

Install a lancache using a single script, which will set up and configure:

- nginx
- [Luameter](https://luameter.com/demo) (if provided)
- sniproxy

## Requirements

- Ubuntu Server 16.04

## Installation

1. `git clone https://github.com/zeropingheroes/lancache-installer.git && cd lancache-installer`

## Configuration

All configuration is done via environment variables:

1. `cp .env.example .env`
2. `nano .env`

Alternatively set the environment variables manually by running:

`export VARIABLE=value`

## Usage

`sudo ./lancache-installer.sh`

