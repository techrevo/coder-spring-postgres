# Coder workspace for Spring application with PostgreSQL database

Provision a full Spring Boot template with Web & Jpa dependencies and an auto-configured PostgreSQL database. All running in Docker containers.

## Prerequisites

- Coder installed and configured
- Docker installed and running

## Architecture

From this template you create two Docker containers, one for Spring application and another for PostgreSQL database. Spring application files are taken from [Spring Initializr](https://start.spring.io) and some parameters are customizable:

- Builder engine (Maven o Gradle)
- Application name
- Organization identifier
- PostgreSQL database password

Other parameters like Java and Spring Boot versions are not customizable for now.

### Spring application

Spring application files are taken from Spring Initializr as they are without any change except for `application.resources` in which are inserted database connection strings for a ready-to-use project.

### Database

Database user is taken from Coder installation and it is equal to your username in lowercase while database name is equal to application one (so, not the workspace name). For example, if your workspace is named `Project Zero`, your Spring application `webapp` and your Coder username is `carlo`, then your database name will be `webapp`, the user `carlo` and the password the one chosen. Anyway you can find this information in `application.resources`, as said before. 

## Usage

After built the workspace via Coder you can access it via VS Code Desktop, Server or an emulated terminal. Once started, you can also access Spring Boot application via a dedicated button on the main panel as explained below.

### VS Code Extensions 

In VS Code Server (code-server) are installed the following extensions:

- Language Support for Java(TM) by Red Hat (`redhat.java`)
- Spring Boot Tools (`vmware.vscode-spring-boot`)
- Database Client (`cweijan.vscode-database-client2`)

### Spring Proxy and subdomains

This template uses [Coder wildcard access](https://coder.com/docs/admin/configure#wildcard-access-url) to allow user to interact via HTTP with Spring application. After started Spring app you can access it by using "Web App" button alongside with VS Code Server button. The URL shown in the window can be used for all HTTP requests.

> **Note**
> For now, in order to allow this service, Docker Spring container exposes 8080 port on the host. If this port is already used, you can change it in terraform configuration file. 
> In the future I will allow the user to choose the port or to use the first free port from the host.

## Conclusions

I am open to the improvements you will suggest via the issues page. In addition, let feel free to fork this repository. 
