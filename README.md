# Olaf
[![Gem Version](https://badge.fury.io/rb/olaf.svg)](https://badge.fury.io/rb/olaf)
[![CircleCI](https://circleci.com/gh/carwow/olaf.svg?style=shield&circle-token=:circle-ci-badge-token)](https://circleci.com/gh/carwow/olaf)



Olaf is a small Ruby wrapper for Snowflake queries.

![Olaf](https://user-images.githubusercontent.com/56375/96335285-8c86f080-106f-11eb-9489-999a884f1246.jpg)


## Dependencies

`olaf` requires Ruby 2.6 or later, `sequel` and `odbc` driver to connect with DBs.

Install dependencies using `bundler` is easy as run:

    bundle install

## Installation

If you don't have Olaf, try this:

    $ gem install olaf

## Getting started

Olaf helps developers to represent Snowflake queries as objects, to have more
control in the code and in tests.

### Example

```ruby
class FetchUsers
  include Olaf::QueryDefinition

  template './snowflake/users_in_department.sql'

  attribute :department_id

  row_object User
end

query = FetchUsers.prepare(department_id: 1337)

Olaf.execute(query)
=> [#<User id: 41, department_id: 1337, name: 'Ian'>]
```
