package com.github.msugakov.ohmyfeedback

import io.ktor.http.ContentType
import io.ktor.server.application.Application
import io.ktor.server.application.call
import io.ktor.server.engine.embeddedServer
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
import kotlinx.cli.required
import java.util.Date

class App {
    val greeting: String
        get() {
            return "Hello World!"
        }
}

fun main(args: Array<String>) {
    val parsedArgs = parseArgs(args)

    embeddedServer(Netty, port = parsedArgs.httpPort, host = "0.0.0.0") {
        configureRouting()
    }.start(wait = true)
    println(App().greeting)
}

data class CliOptions(val httpPort: Int)

fun parseArgs(args: Array<String>): CliOptions {
    val parser = ArgParser("ohmyfeedback")
    val httpPort by parser.option(
        ArgType.Int,
        shortName = "p",
        fullName = "http-port",
        description = "HTTP (insecure) port"
    ).default(8080)

    parser.parse(args)

    return CliOptions(httpPort = httpPort)
}

fun Application.configureRouting() {
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
