import std.stdio;

import fffd.flood;

void main(string[] args)
{
	auto inputFilename = args[1];

	auto input = fffd.flood.readLinear(inputFilename);
	immutable BoolMatrix result = fffd.flood.filter(input, 0.08, 4, 0.45, false);

	save(result, inputFilename ~ "_fffd.png");
}
