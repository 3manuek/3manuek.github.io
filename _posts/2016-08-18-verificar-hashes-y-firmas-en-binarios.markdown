---
layout: post
title:  "Verificando descargas a traves de hashes y firmas"
date:   2016-08-18
description: "Caso ejemplo, Bitcoin Core."
tags : [PGP, SHA, Bitcoin]
categories:
- PGP
- Bitcoin
- Security
category: blog
comments: true
permalink: pgp-bitcoint-sha
author: 3manuek
---

## La razón

Bitcoin es en mi opinión, la más reciente y revolucionaria tecnología, que permite
monetizar la capacidad de computo. No voy a entrar en detalles con respecto a
como funciona o como se utiliza, ya que estimo que si llegaste a esta página, es
porque te has topado con [algo como esto](https://bitcoin.org/en/alert/2016-08-17-binary-safety).

El _hasheo_ de binarios y las firmas digitales han estado dando vuelta desde hace
años. Sin embargo, es sorprendente la cantidad de personas que aún no lo toman en serio.

La única herramienta que tenemos como ciudadanos contra la vigilancia de estado
y el ciberterrorismo, es nuestro propio conocimiento. Ya que los estados no pueden
garantizar la protección de datos de sus ciudadanos debido a la constante mejora
de los sistemas de espionaje y avances en materia de ciberataques.

Hay un muy buen tutorial _exclusivo para el Bitcoin Core_ en [reddit](https://www.reddit.com/r/Bitcoin/wiki/verifying_bitcoin_core),
pero está en inglés.

Más allá de Bitcoin, tené en cuenta que la firma de binarios es algo más que rutinario y por consecuencia, recomendable verificar antes de poner código
en producción.

## Obteniendo los _hashes_

Cada proyecto tiene sus formas, pero vamos a seguir las del Bitcoin Core. Al
ir a la página de los [_downloads_](https://bitcoin.org/en/download), vamos a ver
un link a [Verify release signatures](https://bitcoin.org/bin/bitcoin-core-0.12.1/SHA256SUMS.asc), que contiene un archivo con un mensaje en texto claro y una firma codificada. La parte codificada, contiene el texto claro codificado con la firma que descargaremos/importaremos más adelante:

```bash
# Descargo:
curl https://bitcoin.org/bin/bitcoin-core-0.12.1/SHA256SUMS.asc > SHA256SUMS.asc


$ curl https://bitcoin.org/bin/bitcoin-core-0.12.1/SHA256SUMS.asc
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA256

abf0e7336621250702d7a55487c85b8de33c07a30fbc3ecf7f56c97007fcb4ce  bitcoin-0.12.1-linux32.tar.gz
54aca14b7512801ab78cc93f8576e1b66364a890e8017e8a187e4bf0209fd28c  bitcoin-0.12.1-linux64.tar.gz
91d14dcb9b88ca845df450ceb94250bb5c9a0d514d8ca0c55eb480d0ac77ef32  bitcoin-0.12.1-osx64.tar.gz
e1bc86d24dd978d64b511ada68be31057c20789fb9a6a86c40043a32bf77cb05  bitcoin-0.12.1-osx.dmg
08fc3b6c05c39fb975bba1f6dd49992df46511790ce8dc67398208af9565e199  bitcoin-0.12.1.tar.gz
fba73e4825a6421ce6cc1e48b67ff5f2847ae1b520d26272e69f7f25de4f36d1  bitcoin-0.12.1-win32-setup.exe
148fb438a32f1706a366a7825bbc5e770e5f9a20e5694f724a443275976a0791  bitcoin-0.12.1-win32.zip
c6e06f90e41c36c9a447f065952869e2d7d571ab34b86d061ae19ec25b2799d4  bitcoin-0.12.1-win64-setup.exe
d8e1ab9ff65b79c130ec6af8e36626310ffdaf6aacb7a40cfb76e7a63bdfcfd5  bitcoin-0.12.1-win64.zip
-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.4.11 (GNU/Linux)

iQIcBAEBCAAGBQJXEIwgAAoJEJDIAZ42wulkXNcP/Re0iawPi8muiq6J36ZUZKws
KL2nwjCImj91on8wGoTUir1IytuIafA4JMHslos2Ak3za2UKAEZrEfx0dXm/FVql
AgRneYLYedMQ8127UkSho4rxuwjB3h2gR/FGPpPT0PmbNTWOFsKtV1V9zwsCeA9Q
br/ly2BfZHWsS1tpSK5ukP5W0q+Ii2fO4pcfaAsS2y/gc5kyj5hTiKQivwBVXoVA
cyH1splq1foM5BYwOuT/cUKGrpA8fWo7+xOaEhhFBlW0oJaSXcNSK9mVTSI/dQ/2
lINXcWBtotnH6/evS35pAIOe4PHg/URhXNT/Sdfwts4YL5nMtF+SPBrJWadPvx3C
qdSDZKMuM0cDjVg1F4rjoWAxyshWNKKU2J+qkNUBZ1LbpVyDR3Gl4LFwRjaw0wyZ
n6zHonPCtp33ErhsaY0GryHV1pKvL1h6uyDNWHbYpKny4F+TvbyQ6XNVHrx1IAn5
+9UMPB3Q962/8hrRqK95Cs6AJ/D1Wdw9rwEqOC48waDzttYCVknn4L6rGECDdRM4
6pbWNTf3m9lzThWjiuEdNnPoNuKoBD9/UHWW/WRHjT6tbcGqstoyRKTsi8jjmwnC
9g4xWRsTdqYIAL4PBv32T+QYW/YcyRNTT97t/M0aukXxxxjCObehWVmBXVeNn0/9
lvvCgGgSJXtJHxzqcJ2I
=a2/6
-----END PGP SIGNATURE-----
```

Podemos observar que el hash es un algoritmo de SHA256 (justo debajo del _BEGIN PGP SIGNED MESSAGE_). En Linux tenemos el comando `sha256sum`,
pero en Mac vamos a usar (no hay mucha diferencia en el proceso) `shasum`. Lo que vamos a hacer es
hashear los binarios que descargamos y compararlos con la tabla anterior:

```
$ grep $(shasum -a 256 bitcoin-0.12.1-osx.dmg) SHA256SUMS.asc
SHA256SUMS.asc:e1bc86d24dd978d64b511ada68be31057c20789fb9a6a86c40043a32bf77cb05  bitcoin-0.12.1-osx.dmg
```

Hay varios algoritmos de hashing, por lo que dependiendo el proyecto o binarios
que necesites verificar, deberás utilizar uno u otro. Por ejemplo, `md5sum` o `md5` (Mac) son las
herramientas para otro algoritmo llamado _Message-Digest Algorithm 5_.

¡Joya! Ahora vamos a verificar la firma.

## La _firma_

Para la versión que yo tenía bajada, la firma es la key `36C2E964`. En la página
de las descargas, podrás ver las firmas para cada versión. En este caso, la firma
es la de [Wladimir](https://bitcoin.org/laanwj.asc).

Importo:

```
$ gpg --import Downloads/laanwj-releases.asc
gpg: key 36C2E964: public key "Wladimir J. van der Laan (Bitcoin Core binary release signing key) <laanwj@gmail.com>" imported
gpg: Total number processed: 1
gpg:               imported: 1  (RSA: 1)
gpg: 3 marginal(s) needed, 1 complete(s) needed, PGP trust model
gpg: depth: 0  valid:   2  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 2u
```

Verifico el fingerprint (podrás ver el fingerprint en el [anuncio](https://bitcoin.org/en/alert/2016-08-17-binary-safety) o cuando decodifiques el mensaje):

```
$ gpg --fingerprint 01EA5486DE18A882D4C2684590C8019E36C2E964
pub   4096R/36C2E964 2015-06-24 [expires: 2017-02-13]
      Key fingerprint = 01EA 5486 DE18 A882 D4C2  6845 90C8 019E 36C2 E964
uid                  Wladimir J. van der Laan (Bitcoin Core binary release signing key) <laanwj@gmail.com>
```

Con esto sabemos que la firma es válida. Lo que no sabemos es si el mensaje fue
firmado con esta firma. Por suerte esto es más que sencillo, solo necesitamos
ver que podemos decodificar el mensaje utilizando la firma que importamos:

```
Emanuels-iMac:~ emanuel$ gpg --output mensaje  -d Downloads/SHA256SUMS.asc
gpg: Signature made Fri Apr 15 03:37:20 2016 ART using RSA key ID 36C2E964
gpg: Good signature from "Wladimir J. van der Laan (Bitcoin Core binary release signing key) <laanwj@gmail.com>"
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: 01EA 5486 DE18 A882 D4C2  6845 90C8 019E 36C2 E964
```

Podemos ver que el fingerprint concuerda con el del anuncio. Eso es una buena señal.


Contenido del mensaje decodificado éxitosamente:

```
$ cat mensaje
abf0e7336621250702d7a55487c85b8de33c07a30fbc3ecf7f56c97007fcb4ce  bitcoin-0.12.1-linux32.tar.gz
54aca14b7512801ab78cc93f8576e1b66364a890e8017e8a187e4bf0209fd28c  bitcoin-0.12.1-linux64.tar.gz
91d14dcb9b88ca845df450ceb94250bb5c9a0d514d8ca0c55eb480d0ac77ef32  bitcoin-0.12.1-osx64.tar.gz
e1bc86d24dd978d64b511ada68be31057c20789fb9a6a86c40043a32bf77cb05  bitcoin-0.12.1-osx.dmg
08fc3b6c05c39fb975bba1f6dd49992df46511790ce8dc67398208af9565e199  bitcoin-0.12.1.tar.gz
fba73e4825a6421ce6cc1e48b67ff5f2847ae1b520d26272e69f7f25de4f36d1  bitcoin-0.12.1-win32-setup.exe
148fb438a32f1706a366a7825bbc5e770e5f9a20e5694f724a443275976a0791  bitcoin-0.12.1-win32.zip
c6e06f90e41c36c9a447f065952869e2d7d571ab34b86d061ae19ec25b2799d4  bitcoin-0.12.1-win64-setup.exe
d8e1ab9ff65b79c130ec6af8e36626310ffdaf6aacb7a40cfb76e7a63bdfcfd5  bitcoin-0.12.1-win64.zip
```

### Para los _oneLiners_

Siempre hay algun _freak_ que quiere cosas como estas (está para Mac, usar `wget` y `sha256sum` para Linux):

```bash
$ ( curl https://bitcoin.org/bin/bitcoin-core-0.12.1/SHA256SUMS.asc  | gpg -d ; ) 2> /dev/null  | grep $(shasum -a 256 bitcoin-0.12.1-osx.dmg | cut -f1 -d' '  )
e1bc86d24dd978d64b511ada68be31057c20789fb9a6a86c40043a32bf77cb05  bitcoin-0.12.1-osx.dmg
```

## Unas últimas sugerencias

'ta jodida la mano, así que mejor arremangarse y empezar a corroborar toda
esas cosas que descargamos, en especial aquellas que están en la mira.

Listo el pollo. ¡Espero que te haya servido!


{% if page.comments %}
<div id="disqus_thread"></div>
<script>


var disqus_config = function () {
this.page.url = {{ site.url }};  // Replace PAGE_URL with your page's canonical URL variable
this.page.identifier = {{ page.title }}; // Replace PAGE_IDENTIFIER with your page's unique identifier variable
};

(function() { // DON'T EDIT BELOW THIS LINE
var d = document, s = d.createElement('script');
s.src = '//3manuek.disqus.com/embed.js';
s.setAttribute('data-timestamp', +new Date());
(d.head || d.body).appendChild(s);
})();
</script>
<noscript>Please enable JavaScript to view the <a href="https://disqus.com/?ref_noscript">comments powered by Disqus.</a></noscript>
{% endif %}
