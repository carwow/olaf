# Olaf

Olaf is a small Ruby wrapper for warehouse queries, running them in BigQuery.

![Olaf](https://user-images.githubusercontent.com/56375/96335285-8c86f080-106f-11eb-9489-999a884f1246.jpg)


## Dependencies

`olaf` depends on nothing by itself. Each driver loads its own client library,
and only when it is used, so add to your `Gemfile` the ones you configure:

| Driver            | Gems                    | Also needs              |
| ----------------- | ----------------------- | ----------------------- |
| `Olaf::BigQuery`  | `google-cloud-bigquery` |                         |
| `Olaf::Fake`      | —                       |                         |

## Installation

If you don't have Olaf, try this:

    $ gem install olaf

## Getting started

Olaf helps developers to represent warehouse queries as objects, to have more
control in the code and in tests.

### Example

```ruby
class FetchUsers
  include Olaf::QueryDefinition

  template './big_query/users_in_department.sql'

  argument :department_id

  row_object User
end

query = FetchUsers.prepare(department_id: 1337)

Olaf.execute(query)
=> [#<User id: 41, department_id: 1337, name: 'Ian'>]
```

## Configuration

One driver, which every query runs on:

```ruby
Olaf.configure(olaf_driver: Olaf::Fake)  # ideal for testing
```

Or several, which queries pick by name. The ones that don't declare a `driver`
run on the `default:`, the first one given when it is not specified:

```ruby
Olaf.configure(
  drivers: {
    big_query: Olaf::BigQuery.new(project: 'carwow', labels: { service: 'flatmin' }),
    fake: Olaf::Fake.new
  },
  default: :big_query
)

class FetchUsers
  include Olaf::QueryDefinition

  driver :big_query

  template './big_query/users_in_department.sql'

  argument :department_id
end
```

`Olaf.instance(:big_query)` returns that driver. A single configured driver
serves every query, whatever they declare, which is what keeps `Olaf::Fake`
covering all of them in tests:

```ruby
Olaf.configure(olaf_driver: Olaf::Fake)

Olaf.instance.register_result(FetchUsers, [{ id: 41 }])
Olaf.instance.register_result(FetchUsers, [{ id: 42 }], with: { department_id: 1337 })
```

Whichever driver runs the query, a failure it reports is wrapped into
`Olaf::QueryExecutionError`, carrying the query metadata.

## BigQuery

```ruby
Olaf::BigQuery.new(
  project: 'carwow',
  credentials: JSON.parse(ENV['BIGQUERY_CREDENTIALS']),  # ambient Google credentials when omitted
  maximum_bytes_billed: 5 * Olaf::BigQuery::GIGABYTE,    # default: 1 GiB
  labels: { service: 'flatmin', country: 'uk' }
)
```

The query runs as a job, so that it can be capped and labelled:

* Olaf's `:placeholders` are rewritten to BigQuery's `@named` parameters, for
  declared arguments only, and bound as query parameters. Arguments declared
  `as: :literal` are substituted into the SQL before that, as usual.
* Every job is capped with `maximum_bytes_billed`, and labelled with the driver
  labels plus the name of the template. A query that scans more than the cap
  raises its own, which keeps a regression failing instead of quietly costing
  money:

  ```ruby
  driver :big_query, maximum_bytes_billed: 10 * Olaf::BigQuery::GIGABYTE
  ```

`Olaf.execute` returns the rows. `Olaf.instance(:big_query).run(query)` returns
the finished job instead, for its statistics:

```ruby
job = Olaf.instance(:big_query).run(query)
job.bytes_processed
job.cache_hit?
job.data.all.to_a
```
