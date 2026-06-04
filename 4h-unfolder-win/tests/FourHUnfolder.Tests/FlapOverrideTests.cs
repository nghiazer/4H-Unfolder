using FluentAssertions;
using FourHUnfolder.Domain.Models;
using Xunit;

namespace FourHUnfolder.Tests;

public class FlapOverrideTests
{
    // ── Serialize round-trip for every FlapMode ───────────────────────────────

    public static IEnumerable<object[]> AllModes() =>
        Enum.GetValues<FlapMode>().Select(m => new object[] { m });

    [Theory]
    [MemberData(nameof(AllModes))]
    public void RoundTrip_AllModes_DefaultPrimaryFaceId(FlapMode mode)
    {
        var original    = new FlapOverride(mode);
        var serialized  = original.Serialize();
        var deserialized = FlapOverride.Deserialize(serialized);

        deserialized.Should().NotBeNull();
        deserialized!.Mode.Should().Be(mode);
        deserialized.PrimaryFaceId.Should().Be(-1);
    }

    [Theory]
    [MemberData(nameof(AllModes))]
    public void RoundTrip_AllModes_WithPrimaryFaceId(FlapMode mode)
    {
        var original     = new FlapOverride(mode, PrimaryFaceId: 42);
        var deserialized = FlapOverride.Deserialize(original.Serialize());

        deserialized.Should().NotBeNull();
        deserialized!.Mode.Should().Be(mode);
        deserialized.PrimaryFaceId.Should().Be(42);
    }

    // ── Serialize format ──────────────────────────────────────────────────────

    [Fact]
    public void Serialize_ProducesCommaSeparatedString()
    {
        var ov = new FlapOverride(FlapMode.OnOn_ThisSide, 7);
        ov.Serialize().Should().Be("OnOn_ThisSide,7");
    }

    [Fact]
    public void Serialize_DefaultPrimaryFaceId_IsMinusOne()
    {
        new FlapOverride(FlapMode.Default).Serialize().Should().Be("Default,-1");
    }

    // ── Deserialize edge cases ────────────────────────────────────────────────

    [Fact]
    public void Deserialize_UnknownMode_ReturnsNull()
    {
        FlapOverride.Deserialize("NotAMode,0").Should().BeNull();
    }

    [Fact]
    public void Deserialize_EmptyString_ReturnsNull()
    {
        FlapOverride.Deserialize("").Should().BeNull();
    }

    [Fact]
    public void Deserialize_MissingPrimaryFaceId_DefaultsToMinusOne()
    {
        var result = FlapOverride.Deserialize("Default");
        result.Should().NotBeNull();
        result!.PrimaryFaceId.Should().Be(-1);
    }

    [Fact]
    public void Deserialize_NonIntegerPrimaryFaceId_DefaultsToMinusOne()
    {
        var result = FlapOverride.Deserialize("Default,abc");
        result.Should().NotBeNull();
        result!.PrimaryFaceId.Should().Be(-1);
    }

    [Fact]
    public void Deserialize_NegativePrimaryFaceId_Preserved()
    {
        var result = FlapOverride.Deserialize("SwitchPosition,-5");
        result.Should().NotBeNull();
        result!.PrimaryFaceId.Should().Be(-5);
    }

    [Fact]
    public void Deserialize_ExtraCommaFields_Ignored()
    {
        // Extra trailing fields should not crash or alter Mode/PrimaryFaceId
        var result = FlapOverride.Deserialize("Default,3,extraField");
        result.Should().NotBeNull();
        result!.Mode.Should().Be(FlapMode.Default);
        result.PrimaryFaceId.Should().Be(3);
    }
}
