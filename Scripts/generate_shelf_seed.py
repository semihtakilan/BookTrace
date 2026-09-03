#!/usr/bin/env python3
"""Explore raflarının açılış anlık görüntüsünü üretir.

Raflar her kullanıcıda aynı ve neredeyse hiç değişmiyor; yine de uygulamanın
ilk açılışında altı istek gidiyor ve Open Library'nin konu sorgusu yavaş
(ölçülen: 2-4 saniye). Bu script rafları bir kez indirip uygulamayla birlikte
gönderilen bir dosyaya yazıyor: ilk açılış anında doluyor, ağa hiç çıkmıyor ve
çevrimdışı bile çalışıyor. Uygulama seed'i bayat sayıp arka planda tazeliyor.

Alan eşlemesi `OpenLibraryDocument.toDomain()` ile birebir aynı olmalı; ikisi
ayrıldığında `ShelfSeedTests` uyarıyor.

Kullanım:
    python3 Scripts/generate_shelf_seed.py
"""

import json
import pathlib
import sys
import time
import urllib.parse
import urllib.request

# BookSubject.featured ile aynı sırada ve aynı sorgularla.
SUBJECTS = ["fiction", "science fiction", "history", "philosophy", "computers", "biography"]

RESULTS_PER_SHELF = 15
# OpenLibrarySearchEndpoint.coverOversamplingFactor: kapaklıları öne almaya yetecek fazlalık.
OVERSAMPLING_FACTOR = 2
FIELDS = "key,title,author_name,cover_i,first_publish_year,number_of_pages_median"
USER_AGENT = "BookTrace/1.0 (booktrace.help@gmail.com)"

OUTPUT_PATH = pathlib.Path(__file__).resolve().parent.parent / "BookTrace" / "Resources" / "ShelfSeed.json"


def fetch_shelf(subject):
    query = urllib.parse.urlencode({
        "q": f"subject:{subject}",
        "fields": FIELDS,
        "limit": RESULTS_PER_SHELF * OVERSAMPLING_FACTOR,
    })
    request = urllib.request.Request(
        f"https://openlibrary.org/search.json?{query}",
        headers={"User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)["docs"]


def to_book(document):
    """`OpenLibraryDocument.toDomain()`in Python karşılığı."""
    key = document.get("key")
    title = (document.get("title") or "").strip()
    if not key or not title:
        return None

    book = {
        "id": f"ol:{key}",
        "title": title,
        "authors": document.get("author_name") or [],
        "subjects": [],
    }

    cover_id = document.get("cover_i")
    if cover_id:
        book["coverURL"] = f"https://covers.openlibrary.org/b/id/{cover_id}-M.jpg"

    pages = document.get("number_of_pages_median")
    if pages:
        book["pageCount"] = pages

    year = document.get("first_publish_year")
    if year:
        book["publishedDate"] = str(year)

    return book


def main():
    shelves = []

    for subject in SUBJECTS:
        print(f"  {subject} ...", end="", flush=True)
        documents = fetch_shelf(subject)

        books, seen = [], set()
        for document in documents:
            book = to_book(document)
            if book and book["id"] not in seen:
                seen.add(book["id"])
                books.append(book)

        # Kapaklılar öne: `OpenLibraryService.books(inSubject:)` ile aynı kural.
        with_covers = [book for book in books if "coverURL" in book]
        without_covers = [book for book in books if "coverURL" not in book]
        books = (with_covers + without_covers)[:RESULTS_PER_SHELF]

        if len(books) < RESULTS_PER_SHELF:
            print(f" YETERSİZ ({len(books)} kitap)")
            return 1

        shelves.append({"subject": subject, "maxResults": RESULTS_PER_SHELF, "books": books})
        print(f" {len(books)} kitap")

        # Open Library kendini tanıtan istemcilere saniyede üç istek veriyor.
        time.sleep(0.5)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps({"shelves": shelves}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"\n{OUTPUT_PATH.relative_to(pathlib.Path.cwd())} yazıldı ({OUTPUT_PATH.stat().st_size:,} bayt)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
