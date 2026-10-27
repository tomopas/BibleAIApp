"""Small optional web-research helper for interpretation generation."""

from __future__ import annotations

from html.parser import HTMLParser
from urllib.parse import parse_qs, quote, unquote, urljoin, urlparse

import httpx


class _SearchParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.results: list[dict[str, str]] = []
        self._current: dict[str, str] | None = None
        self._capture = ""

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        classes = set((attributes.get("class") or "").split())
        if tag == "a" and "result__a" in classes:
            self._current = {
                "title": "",
                "snippet": "",
                "url": urljoin("https://duckduckgo.com", attributes.get("href") or ""),
            }
            self._capture = "title"
        elif tag in ("a", "div") and "result__snippet" in classes and self._current:
            self._capture = "snippet"

    def handle_data(self, data: str) -> None:
        if self._current and self._capture:
            self._current[self._capture] += data

    def handle_endtag(self, tag: str) -> None:
        if tag == "a" and self._current and self._capture == "title":
            self._capture = ""
        elif tag == "div" and self._current and self._capture == "snippet":
            self.results.append({k: v.strip() for k, v in self._current.items()})
            self._current = None
            self._capture = ""


def _canonical_url(url: str) -> str:
    query = parse_qs(urlparse(url).query)
    return unquote(query.get("uddg", [url])[0])


def search_context(query: str, limit: int = 3) -> list[dict[str, str]]:
    """Return short search snippets; failures leave normal generation unaffected."""
    try:
        response = httpx.get(
            f"https://html.duckduckgo.com/html/?q={quote(query)}",
            headers={"User-Agent": "BibleAI research/1.0"},
            timeout=15,
            follow_redirects=True,
        )
        response.raise_for_status()
        parser = _SearchParser()
        parser.feed(response.text)
        results = []
        for result in parser.results:
            if result.get("url"):
                result["url"] = _canonical_url(result["url"])
                results.append(result)
        return results[:limit]
    except (httpx.HTTPError, ValueError):
        return []
