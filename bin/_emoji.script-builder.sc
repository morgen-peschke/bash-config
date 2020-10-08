#!/usr/bin/env amm
// -*- mode: scala -*-
import $ivy.{
  `com.softwaremill.sttp.client::core:2.2.7`,
  `org.typelevel::cats-effect:2.2.0`,
  `org.apache.commons:commons-compress:1.20`,
  `commons-codec:commons-codec:1.15`
}

import org.apache.commons.compress.compressors.bzip2.{
  BZip2CompressorOutputStream => BZip2OutputStream
}

import org.apache.commons.codec.binary.Base64OutputStream
import sttp.client.quick._
import cats.implicits._
import cats.effect._
import scala.xml.{XML, Node}
import java.io.{
  OutputStream,
  PrintWriter,
  ByteArrayOutputStream
}

implicit val CS = IO.contextShift(scala.concurrent.ExecutionContext.global)
implicit val T = IO.timer(scala.concurrent.ExecutionContext.global)

final case class Emoji(glyph: String, shortcut: String) {
  def show: String = s"$shortcut $glyph"
}

def download: IO[String] =
  IO {
    quickRequest
      .get(uri"https://raw.githubusercontent.com/warpling/Macmoji/master/emoji%20substitutions.plist")
      .send()
      .body
  }

def byteArrayOutputStream: Resource[IO, ByteArrayOutputStream] =
  Resource.fromAutoCloseable(IO(new ByteArrayOutputStream))

def base64OutputStream(outputStream: OutputStream): Resource[IO, Base64OutputStream] =
  Resource.fromAutoCloseable(IO(new Base64OutputStream(
    outputStream,
    true,             // encode
    -1,               // no line breaks
    Array.empty[Byte] // line separators ignored
  )))

def compressedOutputStream(outputStream: OutputStream): Resource[IO, BZip2OutputStream] =
  Resource.fromAutoCloseable(IO(new BZip2OutputStream(outputStream)))

def printWriter(outputStream: OutputStream): Resource[IO, PrintWriter] =
  Resource.fromAutoCloseable(IO(new PrintWriter(outputStream)))

def encodedWriter(byteArrayOutputStream: ByteArrayOutputStream): Resource[IO,PrintWriter] =
  for {
    base64 <- base64OutputStream(byteArrayOutputStream)
    compressed <- compressedOutputStream(base64)
    writer <- printWriter(compressed)
  } yield writer

def parse(unparsedXML: String): IO[Node] =
  IO(XML.loadString(unparsedXML))

def extractDefinitions(root: Node): IO[Seq[Emoji]] =
  IO((root \ "array" \ "dict").map { entry =>
    (entry \ "string").map(_.text) match {
      case Seq(glyph, shortcut) => Emoji(glyph, shortcut)
    }
  })

def truncateForTesting(emojis: Seq[Emoji]): IO[Seq[Emoji]] =
  IO(emojis.take(5))

def writeDefinitions(dest: PrintWriter, definitions: Seq[Emoji]): IO[Unit] =
  IO {
    definitions.foreach { emoji =>
      dest.println(emoji.show)
    }
    dest.flush()
  }

def retrieveResults(byteArrayOutputStream: ByteArrayOutputStream): IO[String] =
  IO {
    byteArrayOutputStream.toString()
  }

def compressEmojiDefinitions: IO[String] =
  for {
    unparsed <- download
    parsed <- parse(unparsed)
    definitions <- extractDefinitions(parsed)
    results <- byteArrayOutputStream.use { byteOutputStream =>
      for {
        _ <- encodedWriter(byteOutputStream).use { writer =>
          writeDefinitions(writer, definitions)
        }
        r <- retrieveResults(byteOutputStream)
      } yield r
    }
  } yield results

def buildBashScript(encodedEmojiDefs: String): IO[String] =
  IO {
    s"""|#!/bin/bash
        |
        |ME=$$(basename "$${BASH_SOURCE[0]}")
        |DIR=$$(cd "$$(dirname "$${BASH_SOURCE[0]}")" &>/dev/null && pwd)
        |
        |PREVIEW_COMMAND="$$DIR/$$ME render {+}"
        |
        |function split () {
        |    printf '%s\\n' "$$@"
        |}
        |
        |function render () {
        |    cut -f2 -d' ' |
        |        tr -d '\\'n |
        |        perl -CS -pe 's/..\\K(?=.)/\\N{U+200D}/g'
        |}
        |
        |function main () {
        |    if [ "$$1" = 'render' ]; then
        |        shift
        |        split "$$@"
        |    else
        |        base64 --decode <<EOF | bzcat | fzf -0 -m --preview="$$PREVIEW_COMMAND"
        |$encodedEmojiDefs
        |EOF
        |    fi
        |}
        |
        |main "$$@" | render""".stripMargin
  }

def run: IO[ExitCode] = for {
  encodedEmojiDefs <- compressEmojiDefinitions
  bashScript <- buildBashScript(encodedEmojiDefs)
} yield {
  println(bashScript)
  ExitCode.Success
}

@main
def clean(): Unit = {
  run.unsafeRunSync
}
