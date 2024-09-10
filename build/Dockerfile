FROM eclipse-temurin:17-jdk

RUN apt-get update \
	&& apt-get install -y \
	curl \
	git \
	unzip \
	sudo \
	vim \
	wget \
	&& rm -rf /var/lib/apt/lists/*

ARG USER=coder
RUN useradd --groups sudo --no-create-home --shell /bin/bash ${USER} \
	&& echo "${USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USER} \
	&& chmod 0440 /etc/sudoers.d/${USER}
USER ${USER}
WORKDIR /home/${USER}

ARG APP_NAME=springboot
ARG ORGANIZATION_ID=com.example
ARG BUILDER_TYPE=gradle-project
ARG DATABASE_HOST=springboot
ARG DATABASE_PASS=Coder123

RUN curl -fSsL https://start.spring.io/starter.zip \
    -d name=${APP_NAME} \
    -d packageName=${ORGANIZATION_ID}.${APP_NAME} \
	-d type=${BUILDER_TYPE} \
    -d language=java \
	-d bootVersion=3.3.3 \
	-d dependencies=web,jpa,postgresql \
	-o /tmp/${APP_NAME}.zip && \
    unzip /tmp/${APP_NAME}.zip -d /home/${USER}/${APP_NAME} && \
    rm /tmp/${APP_NAME}.zip

WORKDIR /home/${USER}/${APP_NAME}

RUN echo "spring.datasource.url=jdbc:postgresql://${DATABASE_HOST}:5432/${APP_NAME}" >> src/main/resources/application.properties && \
    echo "spring.datasource.username=${USER}" >> src/main/resources/application.properties && \
    echo "spring.datasource.password=${DATABASE_PASS}" >> src/main/resources/application.properties && \
    echo "spring.jpa.database=postgresql" >> src/main/resources/application.properties && \
    echo "spring.jpa.hibernate.ddl-auto=update" >> src/main/resources/application.properties && \
    echo "spring.datasource.driver-class-name=org.postgresql.Driver" >> src/main/resources/application.properties && \
    echo "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect" >> src/main/resources/application.properties
