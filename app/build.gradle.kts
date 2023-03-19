val ktorVersion = "2.2.4"

plugins {
    application
    kotlin("jvm").version("1.8.10")
    id("io.ktor.plugin").version("2.2.4")
}

group = "com.github.msugakov"
version = "1.0-SNAPSHOT"

application {
    mainClass.set("com.github.msugakov.ohmyfeedback.AppKt")
}

tasks.withType<Jar> {
    manifest {
        attributes["Main-Class"] = "com.github.msugakov.ohmyfeedback.AppKt"
    }
}

repositories {
    mavenCentral()
}

kotlin {
    jvmToolchain(19)
}

dependencies {
    implementation("io.ktor:ktor-server-core:$ktorVersion")
    implementation("io.ktor:ktor-server-netty:$ktorVersion")
    implementation("io.netty:netty-tcnative-boringssl-static:2.0.59.Final:linux-x86_64")
    implementation("io.ktor:ktor-network-tls-certificates:$ktorVersion")

    implementation("org.jetbrains.kotlinx:kotlinx-cli:0.3.5")

    implementation("ch.qos.logback:logback-classic:1.2.11")
}

testing {
    suites {
        val test by getting(JvmTestSuite::class) {
            useKotlinTest("1.8.10")
        }
    }
}
