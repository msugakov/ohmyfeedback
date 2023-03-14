
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
}

testing {
    suites {
        val test by getting(JvmTestSuite::class) {
            useKotlinTest("1.8.10")
        }
    }
}
