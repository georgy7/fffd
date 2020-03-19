/*
    fffd - edge bunches detection tool.
    Copyright (C) 2020  Georgy Ustinov  <georgy.ustinov.hello@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import std.stdio;

import fffd.flood;
import fffd.xyz;

void main(string[] args)
{
	auto inputFilename = args[1];

	auto input = fffd.flood.readLinear(inputFilename);
	immutable BoolMatrix result = fffd.flood.filter(input, 0.08, 4, 0.45, true);

	save(result, inputFilename ~ "_fffd.png");
}
