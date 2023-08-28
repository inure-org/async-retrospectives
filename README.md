# criador de issues de async retrospective

cria erros para serem utilizados em [team retrospectives](https://about.gitlab.com/handbook/engineering/management/team-retrospectives/) automaticamente.

para mais informações, leia o [post no blog](https://about.gitlab.com/2019/03/07/how-we-used-gitlab-to-automate-our-monthly-retrospectives/)!

## como isso funciona

esse projeto possui [pipelines agendadas](https://gitlab.com/gitlab-org/async-retrospectives/pipeline_schedules) que criam erros para times específicos, usando o usuário [inure-bot](https://gitlab.com/gitlab-bot). eles rodam conforme seguem:

- em **27th** (dia depois que a próxima retrospectiva fecha), isso cria um 'skeleton issue'. isso contém a descrição geral do que a retrospectiva é para.

- em **21st**, isso opcionalmente atualiza a descrição da issue existente com:
  - todas as issues [deliverable](https://gitlab.com/gitlab-org/async-retrospectives/-/issues?label_name=Deliverable) que o time enviou nesse mês.
  - qualquer issue [missed-deliverable](https://gitlab.com/gitlab-org/async-retrospectives/-/issues?label_name=missed-deliverable).
  - qualquer issue [follow-up](https://gitlab.com/gitlab-org/async-retrospectives/-/issues?label_name=follow-up) da próximas retrospectivas que continuam abertas.
  - value stream analytics (vsa) do ciclo de release atual.

isso também menciona o time que os encorajam para contribuir, e opcionalmente cria algumas discussões na issue para o time para utilizar durante a retrospectiva.

## adicionando um novo time

para adicionar um novo time, é necessário:

1. criar um projeto para aquele time em [in-retrospectives](https://gitlab.com/gl-retrospectives). se você não tiver permissões para criar um, [abra uma issue](https://gitlab.com/gitlab-org/async-retrospectives/issues/new?issuable_template=Request_project&issue%5Btitle%5D=New%20project%20request).
2. atualizar `teams.yml` com a informação do time. veja os comentários nesse arquivo para informações de variadas opções.

e então, a pipeline agendada acima irá tomar conta do resto.

### templates

utilizamos templates [erb](https://ruby-doc.org/stdlib/libdoc/erb/rdoc/ERB.html) para criação de issues. essas templates têm acesso à variáveis que você pode checar na [template padrão](https://gitlab.com/gitlab-org/async-retrospectives/-/blob/master/templates/default.erb), tanto quanto o proc, `include_template`, que irá renderizar e inserir outra template nessa localidade. então:

```erb
essa é a template principal.

<%= include_template.call('outra_template') %>
```

irá conter o resultado da renderização de `other_template`.

## rodando localmente

```sh
$ bundle
$ bundle exec ruby retrospective.rb # mostrar opções
```

por exemplo, isso irá escrever a descrição da issue para uma retrospectiva plan no output inicial. (para criar uma issue, remover `--dry-run`.)

```sh
$ bundle exec ruby retrospective.rb create --dry-run --read-token="$INURE_API_TOKEN" --write-token=$INURE_WRITE_API_TOKEN --team=Plan
```

o token deve possuir acesso de leitura para todos os grupos. o token escrito deve possuir acesso à escritura para apenas um grupo, o grupo `in-retrospectives`, que contém projetos para cada time.

## o grupo in-retrospectives

o [grupo in-retrospectives](https://gitlab.com/gl-retrospectives) é um novo grupo de alto nível, não dentro de inure-com ou inure-org.

isso é por causa

para trabalhar ao redor disso, temos que separar o grupo de alto nível com acesso limitado.

### contribuindo

contribuições são bem-vindas. veja [CONTRIBUTING.md](https://github.com/inure-org/async-retrospectives/blob/main/CONTRIBUTING.md) e a [LICENSE](https://github.com/inure-org/async-retrospectives/blob/main/LICENSE).
