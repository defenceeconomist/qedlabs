"""Regression cases for citation consolidation and project inheritance."""

from pathlib import Path
import tempfile
import unittest

from validate_bibliography import (
    bibliography_errors, document_errors, parse_with_pandoc, validate,
)
from extract_link_graph import build_payload


class BibliographyTests(unittest.TestCase):
    def test_duplicate_keys_are_not_silently_overwritten(self):
        entries = parse_with_pandoc(
            "@book{same, title={First}}\n@book{same, title={Second}}", "biblatex", "csljson"
        )
        self.assertIn("Duplicate bibliography key: same", bibliography_errors(entries))

    def test_distinct_chapters_may_share_a_doi(self):
        entries = parse_with_pandoc(
            "@incollection{chapter1, title={One}, doi={10.1000/book}}\n"
            "@incollection{chapter2, title={Two}, doi={10.1000/book}}", "biblatex", "csljson"
        )
        self.assertEqual(bibliography_errors(entries), [])

    def test_citations_ignore_code_and_accept_crossrefs(self):
        source = "[@valid, p. 12; -@missing]. @fig-example\n\n`@notacitation`\n\n```r\n@code\n```"
        self.assertEqual(document_errors(source, {"valid"}), ["Unresolved citation: missing"])

    def test_retired_keys_require_migration(self):
        self.assertEqual(
            document_errors("[@AbadieGard03]", {"abadie2003economic"}),
            ["Retired citation AbadieGard03; use abadie2003economic"],
        )

    def test_removed_bibliography_links_fail(self):
        self.assertEqual(document_errors("[Old source](../../references.bib)", set()),
                         ["Reference to removed bibliography: ../../references.bib"])

    def test_nested_pages_inherit_and_overrides_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "docs"
            nested = root / "notes" / "topic"
            nested.mkdir(parents=True)
            (root.parent / "evaluation-bibliography.bib").write_text("@book{valid, title={A book}}")
            (root / "_quarto.yml").write_text("bibliography: ../evaluation-bibliography.bib\n")
            page = nested / "index.qmd"
            page.write_text('---\ntitle: Nested\n---\n\n[@valid]\n')
            self.assertEqual(validate(root)[0], [])
            (nested / "_metadata.yml").write_text("bibliography: missing.bib\n")
            self.assertTrue(any("Directory bibliography override" in error for error in validate(root)[0]))
            (nested / "_metadata.yml").unlink()
            page.write_text('---\ntitle: Nested\nbibliography: missing.bib\n---\n\n[@valid]\n')
            self.assertTrue(any("page bibliography override" in error for error in validate(root)[0]))

    def test_graph_shares_canonical_article_but_keeps_chapters_separate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "docs"
            notes = root / "notes"
            notes.mkdir(parents=True)
            (root.parent / "evaluation-bibliography.bib").write_text(
                "@article{abadie2003economic, title={Conflict}}\n"
                "@incollection{chapter1, title={One}, doi={10.1000/book}}\n"
                "@incollection{chapter2, title={Two}, doi={10.1000/book}}\n"
            )
            (notes / "one.qmd").write_text("[@abadie2003economic; @chapter1]")
            (notes / "two.qmd").write_text("[@abadie2003economic; @chapter2]")
            payload = build_payload(root, {"bibliography": "../evaluation-bibliography.bib"}, ["notes/"])
            nodes = {node["id"]: node for node in payload["nodes"]}
            self.assertEqual(nodes["cite:abadie2003economic"]["incoming"], 2)
            self.assertIn("cite:chapter1", nodes)
            self.assertIn("cite:chapter2", nodes)


if __name__ == "__main__":
    unittest.main()
