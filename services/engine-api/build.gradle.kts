plugins {
    java
    id("org.springframework.boot") version "3.4.2"
    id("io.spring.dependency-management") version "1.1.7"
}

group = "com.fortunelog"
version = "0.0.1-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

fun loadDotEnv(envFile: File): Map<String, String> {
    if (!envFile.exists()) return emptyMap()
    val map = mutableMapOf<String, String>()
    envFile.readLines().forEach { raw ->
        val line = raw.trim()
        if (line.isEmpty() || line.startsWith("#")) return@forEach

        // Support `export KEY=VALUE` as well.
        val normalized = if (line.startsWith("export ")) line.removePrefix("export ").trim() else line
        val idx = normalized.indexOf('=')
        if (idx <= 0) return@forEach

        val key = normalized.substring(0, idx).trim()
        var value = normalized.substring(idx + 1).trim()
        if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith('\'') && value.endsWith('\''))) {
            value = value.substring(1, value.length - 1)
        }
        if (key.isNotEmpty()) {
            map[key] = value
        }
    }
    return map
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-oauth2-resource-server")
    implementation("org.springframework.boot:spring-boot-starter-actuator")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

// Make IntelliJ "Run" (Gradle bootRun) work out of the box by loading services/engine-api/.env.
// The file is gitignored, so no secrets are committed.
tasks.named<org.springframework.boot.gradle.tasks.run.BootRun>("bootRun") {
    val env = loadDotEnv(file(".env"))
    if (env.isNotEmpty()) {
        environment(env)
    }
}
