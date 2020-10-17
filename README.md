# Olaf
[![Gem Version](https://badge.fury.io/rb/ork.svg)](http://badge.fury.io/rb/ork)
[![Build Status](https://travis-ci.org/emancu/ork.svg)](https://travis-ci.org/emancu/ork)

Olaf is a small Ruby wrapper for Snowflake queries.

![Olaf](https://i.pinimg.com/474x/6a/76/67/6a76672b65bf989b25b1ec0fc8cda3c8.jpg)

## Dependencies

`olaf` requires Ruby 2.2 or later, `sequel` and `odbc` driver to connect with DBs.

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
