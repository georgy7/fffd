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
import std.math;

import fffd.flood;
import fffd.xyz;
import darg;
import mir.ndslice;

struct Options
{
	@Option("help", "h")
	@Help("Prints this help.")
	OptionFlag help;

	@Option("diff", "d")
	@MetaVar("(0, 1) Default: 0.08.")
	@Help("Y (CIE XYZ) sensitivity.")
	float diff;

	@Option("activation-threshold", "a")
	@MetaVar("(0, 1) Default: 0.45.")
	@Help("The fraction of filled pixels within the fill window needed for the white pixel in the output.")
	float activationThreshold;

	@Option("radius", "r")
	@MetaVar("[1, 5] Default: 4.")
	@Help("The fill window margin. The window width equals 2r+1.")
	ubyte radius;

	@Option("denoise")
	@Help("Remove free-standing points.")
	OptionFlag denoise;

	@Argument("input")
	@Help("Input file or \"-\" for reading from STDIN (maximum 50 MiB).")
	string input;

	@Argument("output")
	@Help("Output file or \"-\" for writing to STDOUT.")
	string output;
}

enum defaultDiff = 0.08;
enum defaultActivationThreshold = 0.45;
enum defaultRadius = 4;

immutable usage = usageString!Options("fffd");
immutable help = helpString!Options("Edge bunches detection tool. The key part of https://jpegbeautifier.net/");

int main(string[] args)
{
	Options options;

	try
	{
		options = parseArgs!Options(args[1 .. $]);

		if (isNaN(options.diff))
		{
			options.diff = defaultDiff;
		}

		if (isNaN(options.activationThreshold))
		{
			options.activationThreshold = defaultActivationThreshold;
		}

		if (0 == options.radius)
		{
			options.radius = 4;
		}
		else if (options.radius > 5)
		{
			stderr.writeln("Radius is limited to 5 for optimization: (5+1+5)*(5+1+5) < 128.");
			return 1;
		}

		Slice!(float*, 3) linearInput;

		if ("-" == options.input)
		{
			const auto maxSize = 1024 * 1024 * 50;
			ubyte[] readFromStdin = stdin.rawRead(new ubyte[maxSize + 1]);

			if (readFromStdin.length > maxSize)
			{
				stderr.writeln("Maximum STDIN size exceeded.");
				return 1;
			}

			linearInput = fffd.flood.readLinearFromBuffer(readFromStdin);
		}
		else
		{
			linearInput = fffd.flood.readLinear(options.input);
		}

		immutable BoolMatrix result = fffd.flood.filter(
			linearInput, options.diff, options.radius, options.activationThreshold, options.denoise
		);

		if ("-" == options.output) {
			savePngToStdout(result);
		} else {
			save(result, options.output);
		}

		return 0;
	}
	catch (ArgParseError e)
	{
		stderr.writeln();
		stderr.writeln(e.msg);
		stderr.writeln();
		stderr.writeln(usage);
		stderr.writeln();
		stderr.writeln();
		return 1;
	}
	catch (ArgParseHelp e)
	{
		// Help was requested
		writeln();
		writeln(usage);
		write(help);

		writeln();
		writeln("You may get access to the source code of this application");
		writeln("at https://github.com/georgy7/fffd");
		writeln();
		writeln();
		writeln();
		return 0;
	}
}
