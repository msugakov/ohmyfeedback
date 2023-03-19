package com.github.msugakov.ohmyfeedback

import io.ktor.http.ContentType
import io.ktor.network.tls.certificates.buildKeyStore
import io.ktor.network.tls.certificates.saveToFile
import io.ktor.server.application.Application
import io.ktor.server.application.call
import io.ktor.server.engine.applicationEngineEnvironment
import io.ktor.server.engine.connector
import io.ktor.server.engine.embeddedServer
import io.ktor.server.engine.sslConnector
import io.ktor.server.http.content.defaultResource
import io.ktor.server.http.content.resources
import io.ktor.server.http.content.static
import io.ktor.server.http.content.staticBasePackage
import io.ktor.server.netty.Netty
import io.ktor.server.response.respondText
import io.ktor.server.routing.get
import io.ktor.server.routing.routing
import kotlinx.cli.ArgParser
import kotlinx.cli.ArgType
import kotlinx.cli.default
import java.io.File
import java.security.KeyStore
import java.util.*

class App {
    val greeting: String
        get() {
            return "Hello World!"
        }
}

fun main(args: Array<String>) {
    val parsedArgs = parseArgs(args)

    val keyStore = genSelfSignedCert()

    val environment = applicationEngineEnvironment {
        connector {
            port = parsedArgs.httpPort
        }
        sslConnector(
            keyStore = keyStore,
            keyAlias = "sampleAlias",
            keyStorePassword = { "123456".toCharArray() },
            privateKeyPassword = { "foobar".toCharArray() }) {
            port = parsedArgs.httpsPort
            keyStorePath = File("var/tmp/keystore.jks")
        }

        module(Application::module)
    }

    embeddedServer(Netty, environment).start(wait = true)
    println(App().greeting)
}

data class CliOptions(val httpPort: Int, val httpsPort: Int)

fun parseArgs(args: Array<String>): CliOptions {
    val parser = ArgParser("ohmyfeedback")
    val httpPort by parser.option(
        ArgType.Int,
        shortName = "p",
        fullName = "http-port",
        description = "HTTP (insecure) port"
    ).default(8080)
    val httpsPort by parser.option(
        ArgType.Int,
        shortName = "s",
        fullName = "https-port",
        description = "HTTPS (TLS) port"
    ).default(8443)

    parser.parse(args)

    return CliOptions(httpPort = httpPort, httpsPort = httpsPort)
}

fun genSelfSignedCert(): KeyStore {
    val keyStoreFile = File("var/tmp/keystore.jks")
    val keyStore = buildKeyStore {
        certificate("sampleAlias") {
            password = "foobar"
            domains = listOf("127.0.0.1", "0.0.0.0", "localhost", "152.70.58.209")
        }
    }
    keyStore.saveToFile(keyStoreFile, "123456")

    return keyStore
}

fun Application.module() {
    routing {
        get("/") {
            call.respondText("<h1>Hello, Ktor! It's ${Date()}</h1>\n", ContentType.Text.Html)
        }
        static("/") {
            staticBasePackage = "static"
            resources(".")
            defaultResource("index.html")
        }
    }
}
