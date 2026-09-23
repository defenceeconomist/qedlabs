#!/usr/bin/env python3
"""Regression tests for portable Quarto and R Jupyter lab downloads."""
import io
import json
from pathlib import Path
import re
import tempfile
import unittest
import zipfile

import yaml
import generate_lab_notebooks as gen


class NotebookTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = gen.LABS_DIR / "difference-in-differences-foundations-lab.qmd"
        cls.notebook = gen.build_notebook(cls.path)

    def test_r_kernel_and_chunk_order(self):
        gen.validate_notebook(self.notebook, self.path)
        self.assertEqual(self.notebook["metadata"]["kernelspec"]["name"], "ir")
        code = ["".join(c["source"]) for c in self.notebook["cells"] if c["cell_type"] == "code"]
        self.assertIn("data_helpers", code[0])
        self.assertIn('qed_data("injury")', code[1])

    def test_clean_jupyter_markdown(self):
        text = "\n".join("".join(c["source"]) for c in self.notebook["cells"] if c["cell_type"] == "markdown")
        self.assertNotIn("[@", text)
        self.assertNotIn("::: ", text)
        self.assertNotIn(".cta-button", text)
        self.assertNotIn("<!-- lab-downloads", text)
        self.assertIn("Meyer", text)
        self.assertIn("difference-in-differences.html", text)

    def test_figures_and_clean_outputs(self):
        code = [c for c in self.notebook["cells"] if c["cell_type"] == "code"]
        self.assertTrue(any("repr.plot.width = 9" in "".join(c["source"]) for c in code))
        self.assertTrue(all(c["outputs"] == [] and c["execution_count"] is None for c in code))

    def test_deterministic_generation(self):
        self.assertEqual(gen.serialize_notebook(self.notebook), gen.serialize_notebook(gen.build_notebook(self.path)))
        files = {"data/x": b"test", "example.qmd": b"document"}
        self.assertEqual(gen.archive(files), gen.archive(files))
        with zipfile.ZipFile(io.BytesIO(gen.archive(files))) as z:
            self.assertEqual(z.read("data/x"), b"test")

    def test_standalone_quarto(self):
        metadata, body = gen.split_front_matter(gen.build_quarto(self.path), self.path)
        self.assertTrue(metadata["execute"]["eval"])
        self.assertEqual(metadata["engine"], "knitr")
        self.assertNotIn("bibliography", metadata)
        self.assertNotIn("aliases", metadata)
        self.assertTrue(metadata["references"])
        self.assertIn("```{r", body)

    def test_mixed_language_and_unclosed_chunks_rejected(self):
        with self.assertRaisesRegex(ValueError, "only R"):
            gen.split_cells("```{python}\nprint(1)\n```", self.path)
        with self.assertRaisesRegex(ValueError, "unclosed"):
            gen.split_cells("```{r}\nx <- 1", self.path)
        with self.assertRaisesRegex(ValueError, "unsupported"):
            gen.split_cells("```{r eval=FALSE}\nx <- 1\n```", self.path)

    def test_ordinary_fenced_examples_are_not_executable(self):
        cells = gen.split_cells("````markdown\n```{r}\nx <- 1\n```\n````", self.path)
        self.assertEqual([kind for kind, _ in cells], ["markdown"])

    def test_worksheets_and_inventory(self):
        self.assertEqual(len(gen.LAB_STEMS), 18)
        self.assertEqual(len(gen.REPORT_STEMS), 5)
        self.assertEqual(len(gen.NOTEBOOK_STEMS), 23)
        for stem in ("synthetic-control-design-lab", "synthetic-control-donor-pool-lab"):
            path = gen.LABS_DIR / (stem+".qmd")
            nb = gen.build_notebook(path)
            gen.validate_notebook(nb, path)
            self.assertFalse(any(c["cell_type"] == "code" for c in nb["cells"]))

    def test_method_reports(self):
        expected_code_cells = {
            "matching-methods-report": 38,
            "difference-in-differences-methods-report": 5,
            "regression-discontinuity-methods-report": 7,
            "synthetic-control-methods-report": 0,
            "interrupted-time-series-methods-report": 7,
        }
        for stem, expected in expected_code_cells.items():
            path = gen.LABS_DIR / (stem + ".qmd")
            notebook = gen.build_notebook(path)
            gen.validate_notebook(notebook, path)
            code = [cell for cell in notebook["cells"] if cell["cell_type"] == "code"]
            self.assertEqual(len(code), expected)
            text = "".join("".join(cell["source"]) for cell in notebook["cells"])
            self.assertNotIn("`r ", text)
            self.assertNotIn("[@", text)

        matching = gen.build_notebook(gen.LABS_DIR / "matching-methods-report.qmd")
        matching_markdown = "\n".join(
            "".join(cell["source"]) for cell in matching["cells"] if cell["cell_type"] == "markdown"
        )
        definitions = re.findall(r"^\[\^([^]]+)\]:", matching_markdown, flags=re.M)
        self.assertEqual(len(definitions), 32)
        self.assertEqual(len(definitions), len(set(definitions)))
        matching_code = "\n".join(
            "".join(cell["source"]) for cell in matching["cells"] if cell["cell_type"] == "code"
        )
        self.assertIn("repr.plot.width = 8.5", matching_code)


if __name__ == "__main__":
    unittest.main()
