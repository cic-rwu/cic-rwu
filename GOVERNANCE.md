# Artificial Intelligence Governance Policy
Cybersecurity and Intel Club at Roger Williams University
https://github.com/cic-rwu
https://cicrwu.org
cic@cicrwu.org

Version 1.0
Effective Date: 2026-10-14

# 1. Purpose and Scope

1.1. This policy governs the use of artificial intelligence ("AI") tools in connection with **Cybersecurity and Intel Club's repositories** (the "Project"), including **contributions, issues, pull requests, comments, security reports, and the use of Project content by AI systems**.

1.2. This policy applies to **every person or automated system that interacts with the Project, repository, issue tracker, discussion forums, or any other communication channel operated by the project**.

1.3. This policy supplements, and **does not replace**, the Project's [LICENSE](LICENSE.md), [CONTRIBUTING](CONTRIBUTING.md), [SECURITY](SECURITY.md), and [CODE-OF-CONDUCT](CODE-OF-CONDUCT.md) (where applicable). Where conflict arises, the `LICENSE` takes precedence.

# 2. Definitions

2.1. "**AI Tool**" means any large language model (LLM), code assistant, autonomous agent, or other generative system capable of producing code, text, images, or other content.

2.2. "**AI-Assisted Content**" means **any** portion of a Contribution that was generated, substantially rewritten, or translated by an AI tool. Simple autocompletion of a single identifier or line, spell-checking, and grammar correction are excluded.

2.3. "**Contribution**" means any code, documentation, configuration, issue, pull request, comment, review, or report submitted to the project.

2.4. "**Contributor**" means the human individual who submits a Contribution.

2.5. "**Autonomous Agent**" means an AI Tool that takes action in Project spaces (e.g., opening pull requests, posting comments, filing issues) without a human reviewing and approving each action beforehand.

2.6. The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC 2119](https://www.rfc-editor.org/info/rfc2119/) and [RFC 8174](https://www.rfc-editor.org/info/rfc8174/).

# 3. General Principle

3.1. Contributors MAY use AI Tools when preparing contributions, subject to the requirements of this Policy.

3.2. Every Contribution MUST have a human in the loop. A human Contributor MUST **read, understand, and approve every part** of a Contribution before it is submitted.

# 4. Accountability

4.1. The Contributor is the author of record for every Contribution, regardless of whether AI Tools were used. The Contributor **bears full responsibility for its correctness, security, quality, and license compliance**.

4.2. A Contributor MUST be able to **explain and defend any part of their Contribution** during review. A Contributor who cannot explain their Contribution when asked may have it closed without further review.

4.3. AI Tools MUST NOT be listed as an author, co-author, or copyright holder of any Contribution

4.4. Where the project uses a Developer Certificate of Origin (DCO), only the human Contributor MAY add a `Signed-off-by` trailer. An AI Tool MUST NOT add, generate, or certify a `Signed-off-by` trailer on the Contributor's behalf.

# 5. Licensing and Provenance

5.1. All Contributions MUST be compatible with the Project's license, as stated in [LICENSE](LICENSE.md).

5.2. By submitting a Contribution, the Contributor represents that they have the right to submit it under the Project's license, and that, to the best of their knowledge, **the Contribution does not reproduce third-party material in violation of that material's license or copyright**.

5.3. Contributors SHOULD review AI-Assises Content for verbatim, or near-verbatim reproduction of existing code, and MUST NOT knowingly submit such content without proper attribution and a compatible license.

5.4. The Maintainer(s) MAY reject any Contribution whose prevenance is uncertain.

# 6. Disclosure

6.1. Contributors MUST disclose the use of AI Tools when a Contribution contains AI-Assisted Content.

6.2. For commits, disclosure SHALL be made using an `Assisted-by` trailer in the commit message, in the following format:
```
Assisted-by: <TOOL NAME>:<MODEL VERSION> [<OTHER TOOLS>]
```

For example,
```
Assisted-by: Claude:claude-opus-5.5
Signed-off-by: John Doe <john@example.net>
```

6.3. For pull requests, issues, and other non-commit Contributions, disclosure SHALL be made in the body of the submission, stating which tool was used, and for what purpose.

6.4. Disclosure exists to assist review. **It is not a penalty**, and a disclosed Contribution SHALL be evaluated on its merits under the same standards as any other Contribution

6.5. Failure to disclose AI-Assisted Content constitutes a violation of this Policy.

# 7. Issues, Pull Requests, and Communications

7.1. Contributors MUST NOT submit issues, pull requests, or comments that consist primarily of unreviewed AI output.

7.2. Contributors MUST verify that any claim, reproduction step, log excerpt, or reference included in a submission is accurate. Fabricated or hallucinated content, including nonexistent functions, files, APIs, or citations, constitutes a violation of this Policy.

7.3. Autonomous Agents MUST NOT open issues, open pull requests, post comments, or submit reviews in Project spaces. AI review tools are permitted only where a human reviews and approves the output before it is posted.

7.4. Contributors SHOULD NOT use AI Tools to complete issues labeled `good first issue`, as those issues exist to help new **human** contributors learn the project.

# 8. Security Reports

8.1. Security vulnerabilities MUST be reported through the process defined in [SECURITY](SECURITY.md) and MUST NOT be disclosed publicly before coordination with the Maintainer(s)

8.2. Contributors MAY use AI Tools to assist in discovering or analyzing vulnerabilities. However, before submitting a security report, the reporter MUST:

(a) personally reproduce the issue against a supported version of the Project, (b) provide a working proof of concept or precise reproduction steps, (c) confirm that the affected code exists as described, and (d) disclose any AI Tool used, per Section 6.

8.3. Reports that are speculative, unreproducible, or describe code that does not exist SHALL be closed without response.

8.4. Any reporter who submits a fabricated or unverified AI-generated security report MAY be permanently barred from submitting further reports, at the sole discretion of the Maintainer(s).

8.5. The Project does not offer monetary rewards for vulnerability reports unless explicitly stated in SECURITY.md.

# 9. Maintainer Use of AI Tools

9.1. The Maintainer(s) MAY use AI Tools to assist in review, triage, and documentation, subject to the same disclosure and human-in-the-loop requirements that apply to Contributors.

9.2. AI Tools SHALL NOT be the sole basis for accepting or rejecting a Contribution, or for any decision regarding a Contributor's standing, access, or permissions within the Project.

# 10. Enforcement

10.1. The Maintainer(s) MAY take any of the following actions in response to a violation of this Policy, at their sole discretion and without prior notice:

(a) request revision or disclosure, (b) close or reject the Contribution, (c) revert a merged Contribution, (d) temporarily or permanently restrict the Contributor from participating in the Project.

10.2. Repeated or deliberate violations, including undisclosed AI use or submission of fabricated content, SHALL be treated as a violation of the CODE_OF_CONDUCT.md.

10.3. Concerns about possible violations SHOULD be reported privately to <CONTACT_EMAIL>.

11. Amendments

11.1. The Maintainer(s) MAY amend this Policy at any time. Amendments take effect upon being merged into the default branch of the repository.

11.2. Contributions submitted before an amendment SHALL be evaluated under the version of this Policy in effect at the time of submission.

12. Disclaimer

12.1. This Policy is a statement of project governance. It is not legal advice and does not create any contractual relationship between the Project and any Contributor or third party beyond what is established by the LICENSE.

References

This Policy was informed by the following public policies. No text was copied verbatim.

[Linux Kernel, AI Coding Assistants](https://docs.kernel.org/next/process/coding-assistants.html)
[Fedora Project, AI-Assisted Contributions Policy](https://docs.fedoraproject.org/en-US/council/policy/ai-contribution-policy/)
[LLVM Project, AI Tool Use Policy](https://llvm.org/docs/AIToolPolicy.html)
[QEMU, Code Provenance: Use of AI Content Generators](https://www.qemu.org/docs/master/devel/code-provenance.html#use-of-ai-content-generators)
[curl, security reporting and AI-generated reports](https://daniel.haxx.se/blog/2024/01/02/the-i-in-llm-stands-for-intelligence/)
