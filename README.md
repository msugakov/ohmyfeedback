# ohmyfeedback

Build fat jar:

```shell
./gradlew buildFatJar
```

Resulting file is in `app/build/libs/app-all.jar`.

Run with arguments:

```shell
./gradlew run --args="--cert-keystore secrets/keystore.jks"
```

Deploy to a remote server:

```shell
scripts/deploy.sh
```
