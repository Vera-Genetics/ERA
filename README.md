# ERA: Epigenetic Reprogramming Atlas for Longevity

ERA is an open access, open source, community-driven knowledgebase for the
clinical and biological interpretation of **epigenetic reprogramming**
interventions and their effect on aging. Our goal is to centralize, debate, and
curate the evidence linking reprogramming factors, chemical cocktails, delivery
strategies, and epigenetic marks to rejuvenation, lifespan, and healthspan
outcomes — so that this knowledge is not repeatedly rebuilt inside private
databases, but developed in the open.

ERA is a **fork of [CIViC](https://civicdb.org/) (Clinical Interpretations of
Variants in Cancer)**, developed by the Griffith Lab at the McDonnell Genome
Institute, Washington University School of Medicine. We are deeply grateful for
their work and for releasing both the data and the platform openly. ERA reuses
CIViC's curation and moderation model — community curators propose evidence,
editors review it — and adapts the domain from cancer variants to epigenetic
reprogramming and longevity.

## Status

ERA is in early development. The data model, ontologies, and curation guidelines
are still being defined. Expect breaking changes.

## Contributing

**We are looking for people to help build ERA.** If any of the following sounds
like you, please open an issue or start a discussion:

- **Aging / epigenetics researchers** — help design the evidence model and
  curation guidelines, and curate the first entries.
- **Curators** — read the literature on partial reprogramming (OSK/OSKM,
  chemical reprogramming, base-editing of the epigenome, etc.) and enter
  structured evidence.
- **Developers** — Rails / GraphQL / Angular. Help adapt the CIViC codebase:
  reworking the variant/feature domain into reprogramming interventions, marks,
  and outcomes.
- **Ontology / data engineers** — map ERA onto existing ontologies (cell types,
  tissues, aging hallmarks, assays).

## Donations

ERA is unfunded and volunteer-run. If you would like to support the project,
you can donate ETH (or any EVM-chain token) to:

```
0xDeCda8d1139e34Fb85B55eeAE23Dd08280475C1C
```

## Getting Started

ERA is a Rails 8 backend serving a single GraphQL API (`POST /api/graphql`) to an
Angular 20 frontend. The same API that powers the frontend is available for
anyone to use; the easiest way to explore it is the GraphiQL interface at
`/api/graphiql`.

### Dependencies

* Ruby >= 4.0 (recommended install via rbenv)
* PostgreSQL >= 14
* Elasticsearch (required for the test suite and search)
* Node >= 22

### Installing

* In `server/`
    *  `gem install bundler && rbenv rehash`
    *  `bundle install`
    *  `rails db:create`
    *  `rails db:schema:load`
    *  `rails s` to start the server. It will be running on `127.0.0.1:3000`.

* In `client/`
    *  `npm install -g yarn`
    *  `yarn install`
    *  `yarn start` will start the dev server at `127.0.0.1:4200` and proxy API requests to the backend

### Development

The backend Rails application uses `rubocop` for linting and formatting, `brakeman` for vulnerability scanning.

In the server directory you can run `./bin/rubocop -a` to autocorrect any formatting issues before pushing. If you want it to run automatically you can set up the [pre-commit](https://pre-commit.com) framework, or use an editor integration such as [conform.nvim](https://github.com/stevearc/conform.nvim) or [vscode-rubocop](https://github.com/rubocop/vscode-rubocop). Alternatively, if you want something more lightweight, an example pre-commit script is provided at `server/.pre-commit-sample`. This can simply be copied into `.git/hooks/pre-commit`.

If the CI fails with a `brakeman` vulnerability, you will need to fix it. If it is a false positive, or not actually an issue, you can mark it as such. From the `server` directory you can run `./bin/brakeman -I`. This will display each warning to you. If you select the `n` option you can provide a note explaining why it should be skipped. This will get added to the `config/brakeman.ignore` file. Commit and push it and the CI will pass.

For `git blame` purposes, you will likely want to ignore the commits where linting and formatting was initially applied. This can be done by running the command `git config blame.ignoreRevsFile .git-blame-ignore-revs` from the project root.

## Acknowledgements

ERA is built on the [CIViC](https://github.com/griffithlab/civic-v2) codebase.
Please also refer to and cite the original CIViC publication in
[Nature Genetics](http://www.nature.com/ng/journal/v49/n2/full/ng.3774.html).

## License

Following CIViC, all curated content in ERA is released under the
[Creative Commons Public Domain Dedication (CC0 1.0 Universal)](https://creativecommons.org/publicdomain/zero/1.0/),
and the source code is licensed under the
[MIT License](http://opensource.org/licenses/MIT).
