module fffd.linear_srgb_conv;

import std.math;
import mir.ndslice.slice;

private auto srgb_to_linear(float cbNumber) @safe
{
    auto c = cbNumber / 255.0;
    auto a = 0.055;
    if (c <= 0.04045)
    {
        return c / 12.92;
    }
    else
    {
        return pow((c + a) / (1 + a), 2.4);
    }
}

private float float_to_byte(float a) @safe
{
    import std.algorithm.comparison;
    return max(min(round(255.0 * a), 255.0), 0.0);
}

float linear_to_srgb_gamma_correction(float lin) @safe
{
    auto a = 0.055;
    if (lin <= 0.0031308) {
        return lin * 12.92;
    } else {
        return pow(lin, 1.0 / 2.4) * (1 + a) - a;
    }
}

float linear_to_srgb(float lin)
{
    return float_to_byte(linear_to_srgb_gamma_correction(lin));
}

Slice!(float*, 3) to_linear(Slice!(float*, 3) rgba)
{
    import std.range;

    auto rows = rgba.length!0;
    auto columns = rgba.length!1;
    auto result = repeat(0f, (rows * columns * 4)).array.sliced(rows, columns, 4);

    foreach (i; 0 .. rows)
    foreach (j; 0 .. columns)
    {
        result[i][j][0] = srgb_to_linear(rgba[i][j][0]);
        result[i][j][1] = srgb_to_linear(rgba[i][j][1]);
        result[i][j][2] = srgb_to_linear(rgba[i][j][2]);
        result[i][j][3] = rgba[i][j][3] / 255.0;
    }

    return result;
}

Slice!(float*, 3) from_linear(Slice!(float*, 3) linear_rgba)
{
    import std.range;

    auto rows = linear_rgba.length!0;
    auto columns = linear_rgba.length!1;
    auto result = repeat(0f, (rows * columns * 4)).array.sliced(rows, columns, 4);

    foreach (i; 0 .. rows)
    foreach (j; 0 .. columns)
    {
        result[i][j][0] = linear_to_srgb(linear_rgba[i][j][0]);
        result[i][j][1] = linear_to_srgb(linear_rgba[i][j][1]);
        result[i][j][2] = linear_to_srgb(linear_rgba[i][j][2]);
        result[i][j][3] = float_to_byte(linear_rgba[i][j][3]);
    }

    return result;
}
