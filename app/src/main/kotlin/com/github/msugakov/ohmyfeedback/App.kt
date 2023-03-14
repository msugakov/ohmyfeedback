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
import java.util.Date

class App {
    val greeting: String
        get() {
            return "Hello World!"
        }
}

fun main(args: Array<String>) {
    embeddedServer(Netty, port = 8080, host = "0.0.0.0") {
        configureRouting()
    }.start(wait = true)
    println(App().greeting)
}

fun Application.configureRouting() {
    routing {
        get("/") {
            call.respondText("<h1>Hello, Ktor! It's ${Date()}</h1>", ContentType.Text.Html)
        }
        static("/") {
            staticBasePackage = "static"
            resources(".")
            defaultResource("index.html")
        }
    }
}
