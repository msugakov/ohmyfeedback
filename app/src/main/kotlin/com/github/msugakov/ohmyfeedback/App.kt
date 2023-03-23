package com.github.msugakov.ohmyfeedback

import io.ktor.http.ContentType
import io.ktor.network.tls.certificates.buildKeyStore
import io.ktor.network.tls.certificates.saveToFile
import io.ktor.server.application.Application
import io.ktor.server.application.call
import io.ktor.server.application.createApplicationPlugin
import io.ktor.server.application.install
import io.ktor.server.engine.ApplicationEngineEnvironmentBuilder
import io.ktor.server.engine.applicationEngineEnvironment
import io.ktor.server.engine.connector
import io.ktor.server.engine.embeddedServer
import io.ktor.server.engine.sslConnector
import io.ktor.server.http.content.defaultResource
import io.ktor.server.http.content.resources
import io.ktor.server.http.content.static
import io.ktor.server.http.content.staticBasePackage
import io.ktor.server.netty.Netty
import io.ktor.server.plugins.httpsredirect.HttpsRedirect
import io.ktor.server.request.host
import io.ktor.server.response.respondRedirect
import io.ktor.server.response.respondText
import io.ktor.server.routing.get
import io.ktor.server.routing.routing
import io.ktor.server.util.url
import kotlinx.cli.ArgParser
import kotlinx.cli.ArgType
import kotlinx.cli.default
import org.slf4j.LoggerFactory
import java.io.File
import java.io.FileInputStream
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.util.*

class App {
    val greeting: String
        get() {
            return "Hello World!"
        }
}

val log = LoggerFactory.getLogger("main")

fun main(args: Array<String>) {
    val parsedArgs = parseArgs(args)

    val environment = applicationEngineEnvironment {
        connector {
            port = parsedArgs.httpPort
        }
        initSslConnector(this, parsedArgs)

        module {
            module(parsedArgs.httpsPort)
        }
    }

    embeddedServer(Netty, environment).start(wait = true)
}

data class CliOptions(val httpPort: Int, val httpsPort: Int, val certKeyStore: String?)

fun parseArgs(args: Array<String>): CliOptions {
    val parser = ArgParser("ohmyfeedback")

    val httpPort by parser.option(
        ArgType.Int,
        shortName = "p",
        fullName = "http-port",
        description = "HTTP (insecure) port",
    ).default(8080)

    val httpsPort by parser.option(
        ArgType.Int,
        shortName = "s",
        fullName = "https-port",
        description = "HTTPS (TLS) port",
    ).default(8443)

    val certKeyStore by parser.option(
        ArgType.String,
        fullName = "cert-keystore",
        description = "Load TLS certificate from the specified keystore file instead of generating self-signed one",
    )

    parser.parse(args)

    return CliOptions(httpPort = httpPort, httpsPort = httpsPort, certKeyStore = certKeyStore)
}

fun initSslConnector(builder: ApplicationEngineEnvironmentBuilder, args: CliOptions) {
    val keyAlias = "sampleAlias"
    val ksPass: String
    val keyPass: String
    val keyStore: KeyStore

    if (args.certKeyStore != null) {
        log.debug("Will use {} as cert keystore", args.certKeyStore)
        ksPass = File(args.certKeyStore + "-pass").readText(StandardCharsets.UTF_8).trimEnd()
        keyPass = ksPass
        keyStore = KeyStore.getInstance(KeyStore.getDefaultType())
        FileInputStream(args.certKeyStore).use { fs -> keyStore.load(fs, ksPass.toCharArray()) }
    } else {
        log.info("Cert keystore is not specified. Will use self-signed certificate.")
        ksPass = "123456"
        keyPass = "foobar"
        keyStore = genSelfSignedCert(ksPass, keyPass, keyAlias)
    }

    builder.sslConnector(keyStore = keyStore,
        keyAlias = keyAlias,
        keyStorePassword = { ksPass.toCharArray() },
        privateKeyPassword = { keyPass.toCharArray() }) {
        port = args.httpsPort
    }
}

fun genSelfSignedCert(ksPass: String, keyPass: String, keyAlias: String): KeyStore {
    val keyStoreFile = File("var/tmp/keystore.jks")
    val keyStore = buildKeyStore {
        certificate(keyAlias) {
            password = keyPass
            domains = listOf("127.0.0.1", "0.0.0.0", "localhost", "ohmyfeedback.net", "ohmyfeedbacks.net")
        }
    }
    keyStore.saveToFile(keyStoreFile, ksPass)

    return keyStore
}

fun Application.module(httpsPort: Int) {
    install(HttpsRedirect) {
        sslPort = httpsPort
        permanentRedirect = false
    }
    install(RedirectSingularPlugin)
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

val RedirectSingularPlugin = createApplicationPlugin("RedirectSingularPlugin") {
    onCall { call ->
        // Inspired by io.ktor.server.plugins.httpsredirect.HttpsRedirect
        if (call.request.host() == "ohmyfeedbacks.net" && !call.response.isCommitted) {
            val redirectUrl = call.url { host = "ohmyfeedback.net" }
            call.respondRedirect(redirectUrl, false)
        }
    }
}
