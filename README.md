# Lancache Installer

Install Lancache using a single script

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

