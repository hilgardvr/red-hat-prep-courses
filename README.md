# RHCSA Field Guide

A free, lab-first course for the **Red Hat Certified System Administrator (RHCSA)** exam, **EX200 v10**, based on **Red Hat Enterprise Linux 10**.

The course teaches the underlying Linux theory first, then turns every exam objective into hands-on practice on disposable RHEL-compatible virtual machines. It is designed for learners starting with little or no Linux experience.

> **Status:** Complete. Foundations **F1–F8**, modules **R1–R12** (the capstone includes three timed mock exams), the validated lab kit, and the printable **Print / PDF** edition are all available. The course covers every objective in the official EX200 v10 list. A free **exam pack** — the objective checklist plus mock exam A, as a PDF — is described on the [subscribe page](docs/subscribe.md).

## What is here

| Path | Purpose |
|---|---|
| `docs/` | Course content, built with MkDocs Material |
| `labs/` | Vagrant + libvirt lab environment, provisioning, and automated checks |
| `mkdocs.yml` | Site configuration and navigation |
| `overrides/` | Theme overrides: analytics hook and subscribe-form guard |
| `bin/pdf` | Builds the PDF editions from the print page |
| `print/` | Print-page banner and the paged-media stylesheet |
| `requirements.txt` | Python dependencies for the site |
| `requirements-pdf.txt` | Adds WeasyPrint for the PDF builds (not used by CI) |

## Read the course locally

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
mkdocs serve
```

Then open <http://127.0.0.1:8000>.

To build the static site:

```bash
mkdocs build --strict
```

The output is written to `site/`.

### Print or PDF

The site also builds a single **Print / PDF** page that combines every page in course order. Open it from the last item in the site navigation, then use your browser's **File → Print → Save as PDF**. It is generated at build time by `mkdocs-print-site-plugin`, so it always matches the published pages and needs no separate export step.

### Typeset PDF editions

Two PDFs are built from that print page with WeasyPrint: a **free sample** (the objective checklist plus mock exam A) and the **complete field guide**.

```bash
pip install -r requirements-pdf.txt
.venv/bin/python bin/pdf sample     # dist/rhcsa-sample-YYYY-MM.pdf
.venv/bin/python bin/pdf full       # dist/rhcsa-field-guide-YYYY-MM.pdf
```

The PDF builds are local only. CI installs `requirements.txt`, so the published site needs neither WeasyPrint nor its system libraries; the PDFs are attached to a GitHub Release when they change.

## Deploy to GitHub Pages

The workflow in `.github/workflows/pages.yml` builds the site on every push to `main` and deploys it with GitHub Pages.

1. Push the repository to GitHub.
2. Open **Settings → Pages** and set **Source** to **GitHub Actions**.
3. Push to `main`, or run the workflow manually from the **Actions** tab.

The workflow sets `SITE_URL` from the repository owner and name, so the generated 404 page and canonical URLs use the correct project path. If you use a custom domain, set `SITE_URL` in the workflow or change the fallback in `mkdocs.yml`.

## Run the labs

The lab kit needs a Linux host with KVM/libvirt, at least 16 GB of RAM, and Vagrant with the `vagrant-libvirt` provider.

```bash
cd labs
./bin/lab doctor     # check the host
./bin/lab up         # create server + node2
./bin/lab ssh        # log in to server
```

The lab runs **AlmaLinux 10**, a free RHEL 10-compatible rebuild that requires no subscription. The course targets RHEL 10 for the exam and notes any rebuild difference that matters.

See [`docs/start-here/lab-setup.md`](docs/start-here/lab-setup.md) for the full setup guide.

## Course design

Every module follows the same pattern:

1. Objectives, mapped to the official EX200 bullets
2. Theory and mental models
3. Guided labs with expected output
4. A challenge lab written like an exam task
5. A reboot-persistence test
6. Automated verification (`lab check`)
7. Knowledge check and cheat sheet

A module is only considered complete when its check script passes from a clean lab snapshot.

## Project status and handoff

See [`AGENTS.md`](AGENTS.md) for the current milestone, curriculum status, lab details, decisions, known gaps, and the next steps. It is the maintainer-facing source of truth for humans and future agents.

## Contributing

Content corrections, clearer explanations, and additional verification cases are welcome. Please keep the following rules:

- Original content only. Do not copy Red Hat courseware, exam questions, or instructor materials.
- Every lab must be reproducible from a clean snapshot.
- Every configuration task must include a persistence check.
- Prefer official documentation and `man` pages as references.

## License

- **Code** (lab scripts, site tooling): [MIT](LICENSE)
- **Course content**: [CC BY-NC-SA 4.0](LICENSE-CONTENT)

You may read, share, and adapt the course for non-commercial use with attribution. Commercial redistribution of the core course is not permitted.

## Disclaimer

This is an independent, unofficial study resource. It is not affiliated with, endorsed by, or sponsored by Red Hat, Inc. **Red Hat**, **RHCSA**, **RHCE**, and **Red Hat Enterprise Linux** are trademarks of Red Hat, Inc. Exam objectives and product behavior can change; always confirm the current objectives on the official Red Hat exam page before booking.
