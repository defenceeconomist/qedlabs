#!/usr/bin/env python3
"""Regression checks for language-aware notebook generation."""
import tempfile
import unittest
from pathlib import Path
import generate_lab_notebooks as gen

class NotebookTests(unittest.TestCase):
    def test_existing_r_kernel_and_chunk_order(self):
        p = gen.LABS_DIR / 'difference-in-differences-foundations-lab.qmd'
        nb = gen.build_notebook(p)
        gen.validate_notebook(nb, p)
        self.assertEqual(nb['metadata']['kernelspec']['name'], 'ir')
        self.assertGreater(sum(c['cell_type'] == 'code' for c in nb['cells']), 5)

    def test_python_kernel_and_executable_cells(self):
        p = gen.LABS_DIR / 'difference-in-differences-foundations-python-lab.qmd'
        nb = gen.build_notebook(p)
        gen.validate_notebook(nb, p)
        self.assertEqual(nb['metadata']['kernelspec']['name'], 'python3')
        for cell in nb['cells']:
            if cell['cell_type'] == 'code':
                compile(''.join(cell['source']), str(p), 'exec')
        self.assertEqual(gen.serialize_notebook(nb), gen.serialize_notebook(gen.build_notebook(p)))

    def test_links_and_download_cleanup(self):
        p = gen.LABS_DIR / 'difference-in-differences-foundations-python-lab.qmd'
        text = '[R](difference-in-differences-foundations-lab.qmd#test)\n[Download the Python Jupyter notebook](notebooks/a.ipynb){.cta-button}\n'
        converted = gen.rewrite_markdown(text, p)
        self.assertIn('foundations-lab.html#test', converted)
        self.assertNotIn('Download', converted)
        self.assertNotIn('.qmd', converted)

    def test_unclosed_chunk_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'unclosed'):
            gen.split_cells('```{python}\nprint(1)', gen.LABS_DIR / 'broken.qmd')

    def test_mixed_language_is_rejected(self):
        # Within docs so URL validation remains representative; always remove fixture.
        with tempfile.NamedTemporaryFile(mode='w', suffix='.qmd', dir=gen.LABS_DIR) as file:
            file.write('---\ntitle: Test\nnotebook-language: python\n---\n```{r}\nx <- 1\n```\n')
            file.flush()
            with self.assertRaisesRegex(ValueError, 'disagrees'):
                gen.build_notebook(Path(file.name))

if __name__ == '__main__':
    unittest.main()
