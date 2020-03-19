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

module fffd.adjacent_matrix_holder_test;

unittest
{
    import fluentasserts.core.base;
    import fffd.adjacent_matrix_holder;
    import fffd.bit_utils;
    import std.conv;
    import std.math;
    import std.format;
    import std.stdio;

    const auto holder = new AdjacentMatrixHolder(2);
    const Offset[] offsets = holder.getOffsets();

    offsets.length.should.equal(25);

    foreach (offset1_index; 0 .. offsets.length)
    {
        const Offset offset1 = offsets[offset1_index];

        Bitmask requestMask;
        requestMask.setTrue(to!int(offset1_index));

        const Bitmask adjacentOffsets = holder.getOrResult(requestMask);
        adjacentOffsets.nonZero().should.equal(true, format("offset1_index = %d.", offset1_index));

        foreach (offset2_index; 0 .. offsets.length)
        {
            immutable Offset offset2 = offsets[offset2_index];

            if (((abs(offset1.y - offset2.y) == 1) && (offset1.x == offset2.x))
                    || ((abs(offset1.x - offset2.x) == 1) && (offset1.y == offset2.y)))
            {
                adjacentOffsets.isSet(to!int(offset2_index)).should.equal(true,
                        format("offset1: (%s, %s), offset2 (%s, %s), mask: %s.", offset1.y, offset1.x,
                            offset2.y, offset2.x, adjacentOffsets.toBinaryString()));
            }
            else
            {
                adjacentOffsets.isSet(to!int(offset2_index)).should.equal(false,
                        format("offset1: (%s, %s), offset2 (%s, %s), mask: %s.", offset1.y, offset1.x,
                            offset2.y, offset2.x, adjacentOffsets.toBinaryString()));
            }
        }

        foreach (offset2_index; offsets.length .. 128)
        {
            adjacentOffsets.isSet(to!int(offset2_index)).should.equal(false);
        }
    }

    bitCount(holder.getOriginMask()).should.equal(1);
    bitCount(holder.getNotOriginMask()).should.equal(to!int(offsets.length - 1));

    writeln("Test - AdjacentMatrixHolder(2): Ok.");
}

unittest
{
    import fluentasserts.core.base;
    import fffd.adjacent_matrix_holder;
    import fffd.bit_utils;
    import std.conv;
    import std.math;
    import std.format;
    import std.stdio;

    const auto holder = new AdjacentMatrixHolder(4);
    const Offset[] offsets = holder.getOffsets();

    offsets.length.should.equal(81);

    foreach (offset1_index; 0 .. offsets.length)
    {
        const Offset offset1 = offsets[offset1_index];

        Bitmask requestMask;
        requestMask.setTrue(to!int(offset1_index));

        const Bitmask adjacentOffsets = holder.getOrResult(requestMask);
        adjacentOffsets.nonZero().should.equal(true, format("offset1_index = %d.", offset1_index));

        foreach (offset2_index; 0 .. offsets.length)
        {
            immutable Offset offset2 = offsets[offset2_index];

            if (((abs(offset1.y - offset2.y) == 1) && (offset1.x == offset2.x))
            || ((abs(offset1.x - offset2.x) == 1) && (offset1.y == offset2.y)))
            {
                adjacentOffsets.isSet(to!int(offset2_index)).should.equal(true,
                format("offset1: (%s, %s), offset2 (%s, %s), mask: %s.", offset1.y, offset1.x,
                offset2.y, offset2.x, adjacentOffsets.toBinaryString()));
            }
            else
            {
                adjacentOffsets.isSet(to!int(offset2_index)).should.equal(false,
                format("offset1: (%s, %s), offset2 (%s, %s), mask: %s.", offset1.y, offset1.x,
                offset2.y, offset2.x, adjacentOffsets.toBinaryString()));
            }
        }

        foreach (offset2_index; offsets.length .. 128)
        {
            adjacentOffsets.isSet(to!int(offset2_index)).should.equal(false);
        }
    }

    bitCount(holder.getOriginMask()).should.equal(1);
    bitCount(holder.getNotOriginMask()).should.equal(to!int(offsets.length - 1));

    writeln("Test - AdjacentMatrixHolder(4): Ok.");
}

unittest
{
    import fluentasserts.core.base;
    import fffd.adjacent_matrix_holder;
    import fffd.bit_utils;
    import std.conv;
    import std.math;
    import std.format;
    import std.stdio;

    const auto holder = new AdjacentMatrixHolder(5);
    const Offset[] offsets = holder.getOffsets();

    offsets.length.should.equal(121);

    foreach (offset1_index; 0 .. offsets.length)
    {
        const Offset offset1 = offsets[offset1_index];

        Bitmask requestMask;
        requestMask.setTrue(to!int(offset1_index));

        const Bitmask adjacentOffsets = holder.getOrResult(requestMask);
        adjacentOffsets.nonZero().should.equal(true, format("offset1_index = %d.", offset1_index));

        foreach (offset2_index; 0 .. offsets.length)
        {
            immutable Offset offset2 = offsets[offset2_index];

            if (((abs(offset1.y - offset2.y) == 1) && (offset1.x == offset2.x))
            || ((abs(offset1.x - offset2.x) == 1) && (offset1.y == offset2.y)))
            {
                adjacentOffsets.isSet(to!int(offset2_index)).should.equal(true,
                format("offset1: (%s, %s), offset2 (%s, %s), mask: %s.", offset1.y, offset1.x,
                offset2.y, offset2.x, adjacentOffsets.toBinaryString()));
            }
            else
            {
                adjacentOffsets.isSet(to!int(offset2_index)).should.equal(false,
                format("offset1: (%s, %s), offset2 (%s, %s), mask: %s.", offset1.y, offset1.x,
                offset2.y, offset2.x, adjacentOffsets.toBinaryString()));
            }
        }

        foreach (offset2_index; offsets.length .. 128)
        {
            adjacentOffsets.isSet(to!int(offset2_index)).should.equal(false);
        }
    }

    bitCount(holder.getOriginMask()).should.equal(1);
    bitCount(holder.getNotOriginMask()).should.equal(to!int(offsets.length - 1));

    writeln("Test - AdjacentMatrixHolder(5): Ok.");
}
