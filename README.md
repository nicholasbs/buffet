Buffet
======

A fast and correct personal finance tracker that will one day be an interactive
programming environment.

### TODOs

* Finish tag autocomplete so it works with negations and disjunctions.

* Tag rules should take an optional block, which gets passed a Transaction, and
  which (if the block is present) causes the rule to apply only if the block
  returns true. Or perhaps there should be writing rules with blocks that can
  arbitrarily transform Transactions (e.g., Transaction -> Transaction).

* Consider making types (using `Struct`) for all types, like `Transaction` is
  now.

* Update docs to reflect new output formatting.

* Dynamic widths when printing descriptions and account names (e.g., if the
  longest description in a list of transactions is 20 chars pad all
  descriptions to 20 chars not ~50).

* Add privacy mode (e.g., replace description with... something and possibly do
  other things to make it so you can give demos without revealing personal
  info).

* Document the rest of `BuffetCLI`.

### `buffet repl`

Buffet has a REPL with a simple programming language designed for personal finance.

```
$ buffet repl
```

All Buffet commands in the REPl operate using a single register, *reg*. By default, *reg* stores a list of all the transactions in your database. Buffet prints the value of *reg* after every command.

The simplest program is an empty line:

```
>
-2.25		SMILE TO GO 2017-03-02 Chase (Nick)
-22.0		Dig Inn Liberty Street 2017-03-01 Chase (Nick)
-9.89		GOURMET GARAGE - BROOM 2017-03-01 Chase (Nick)
[...cut...]
>
```

This prints every transaction in your database.

The `last` command takes the last `n` items in *reg*:

```
> last 2
-22.0		Dig Inn Liberty Street 2017-03-01 Chase (Nick)
-9.89		GOURMET GARAGE - BROOM 2017-03-01 Chase (Nick)
>
```

The `reverse` command reverses the order of *reg*:

```
> reverse
-9.89		GOURMET GARAGE - BROOM 2017-03-01 Chase (Nick)
-22.0		Dig Inn Liberty Street 2017-03-01 Chase (Nick)
>
```

The `sum` command replaces *reg* with the sum of its contents:

```
> sum
$31.89
>
```

If *reg* is a list of transactions (as in the above example), `sum` will add up the amounts of all of the transactions in the list.

You can reset the value of *reg* to be your entire database at any time with the `reset` command:

```
> reset
-2.25		SMILE TO GO 2017-03-02 Chase (Nick)
-22.0		Dig Inn Liberty Street 2017-03-01 Chase (Nick)
-9.89		GOURMET GARAGE - BROOM 2017-03-01 Chase (Nick)
[...cut...]
>
```

You can chain commands using the `»` operator:

```
> reset » last 2 » sum
$31.89
```

The `monthly` command groups a list of transactions by month:

```
> reset » monthly » last 3
[...cut for brevity...]
```

The above prints the last three months of your transactions grouped by month.

We can use `sum` to get a more useful view of this data:

```
> sum
02/17	$620.57
03/17	$7274.78
04/17	$11270.71
```

Note that earlier we used `sum` to add up a list of transactions into a single dollar value, but in the example above we used `sum` to add up a table of data (lists of lists of transactions) into a new table of data. In this case, we get the sum of all transactions for each month.

We can use `sum` again to find out the total for the past three months:

```
> sum
$19166.06
```

You can filter by putting the name of a tag in brackets:

```
> reset » [gas]
-43.01    NATIONAL GRID NY UTILITYPAY SEP 16~ Tran 2016-09-20 Checking account
-40.93    NATIONAL GRID NY UTILITYPAY AUG 16~ Tran 2016-08-22 Checking account
-45.77    NATIONAL GRID NY UTILITYPAY JUL 16~ Tran 2016-07-22 Checking account
[...cut for brevity...]
>
```

The above shows only transactions tagged **gas**.

You can filter by multiple tags. For instance, if you want transactions tagged **gas** *or* **internet** :

```
> reset » [gas] [internet]
[... cut for brevity...]
>
```

If you want transactions tagged with *both* **travel** and **wedding** you can chain multiple tags together:

```
> reset » [travel] » [wedding]
-22.15		BP#8124628WYE MILLS BP 9271 - QUEENSTOWN, MD 2016-10-21 Amex
-19.19		SUNOCO 1367302201 1354400002 - E BRUNSWICK, NJ 2016-10-23 Amex
-260.81		HERTZ RENT-A-CAR 2016-09-18 Chase (Kim)
>
```

You can filter *out* a specific tag by using `!`, the negation operator, before a tag:

```
> reset » ![wedding]
[...cut for brevity...]
>
```

The above shows all transactions that are *not* tagged **wedding**.

Thus you can filter to any boolean expression. For example:

```
> reset » ![ignore] » [cash] [food]
[...cut for brevity...]
>
```

The above shows all transactions that are *not* tagged **ignore** and which *are* tagged **cash** *or* **food** (e.g., `!A && (B || C)`).

The `count` command gives the length of *reg*:

```
> reset » [food] » count
773
>
```

In the above example we have 773 transactions tagged **food**.

You can quit the REPL using the `quit` (or `q`) command:

```
> quit
$
```

### License

Copyright 2017, Nicholas Bergson-Shilcock.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
