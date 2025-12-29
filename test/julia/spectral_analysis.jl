#!/usr/bin/env julia
#=
Spectral Analysis for Inharmonic RPM Oscillators
Visualizes FFT spectra and spectrograms to analyze inharmonicity effects

Usage:
  julia spectral_analysis.jl                    # Analyze all WAV files
  julia spectral_analysis.jl file1.wav file2.wav  # Analyze specific files
=#

using WAV
using FFTW
using DSP
using Plots
using Statistics

# Set up output directory
const OUTPUT_DIR = joinpath(@__DIR__, "..", "..", "test_output")
const PLOT_DIR = joinpath(@__DIR__, "plots")
mkpath(PLOT_DIR)

"""
Load a WAV file and return samples and sample rate
"""
function load_wav(filepath::String)
    samples, sr = wavread(filepath)
    # Convert to mono if stereo
    if size(samples, 2) > 1
        samples = vec(mean(samples, dims=2))
    else
        samples = vec(samples)
    end
    return samples, sr
end

"""
Compute magnitude spectrum (dB) for a signal window
"""
function compute_spectrum(samples::Vector{Float64}, sr::Float64;
                          window_size::Int=8192, normalize::Bool=true)
    # Take a window from the middle of the signal (skip attack/decay)
    start_idx = max(1, length(samples) ÷ 4)
    end_idx = min(length(samples), start_idx + window_size - 1)
    window = samples[start_idx:end_idx]

    # Zero-pad if needed
    if length(window) < window_size
        window = vcat(window, zeros(window_size - length(window)))
    end

    # Apply Hann window
    window .*= hanning(window_size)

    # Compute FFT
    spectrum = abs.(fft(window))[1:window_size÷2]

    # Convert to dB
    spectrum_db = 20 .* log10.(spectrum .+ 1e-10)

    # Normalize to 0 dB peak
    if normalize
        spectrum_db .-= maximum(spectrum_db)
    end

    # Frequency axis
    freqs = (0:window_size÷2-1) .* (sr / window_size)

    return freqs, spectrum_db
end

"""
Find harmonic peaks in spectrum
Returns frequencies and amplitudes of peaks
"""
function find_harmonics(freqs::Vector{Float64}, spectrum_db::Vector{Float64},
                        fundamental::Float64; max_harmonics::Int=16, threshold::Float64=-60.0)
    harmonics = Float64[]
    amplitudes = Float64[]
    deviations = Float64[]  # Deviation from ideal harmonic

    for n in 1:max_harmonics
        ideal_freq = fundamental * n

        # Search window around ideal frequency (+/- 5%)
        window_low = ideal_freq * 0.95
        window_high = ideal_freq * 1.05

        mask = (freqs .>= window_low) .& (freqs .<= window_high)
        if sum(mask) == 0
            continue
        end

        # Find peak in window
        window_spectrum = spectrum_db[mask]
        window_freqs = freqs[mask]

        peak_idx = argmax(window_spectrum)
        peak_amp = window_spectrum[peak_idx]
        peak_freq = window_freqs[peak_idx]

        if peak_amp > threshold
            push!(harmonics, peak_freq)
            push!(amplitudes, peak_amp)
            push!(deviations, (peak_freq - ideal_freq) / ideal_freq * 100)  # % deviation
        end
    end

    return harmonics, amplitudes, deviations
end

"""
Compute inharmonicity coefficient B from harmonic deviations
For stiff strings/bars: f_n = n * f_1 * sqrt(1 + B * n^2)
"""
function estimate_inharmonicity(harmonics::Vector{Float64}, fundamental::Float64)
    if length(harmonics) < 3
        return NaN
    end

    # Fit to model: f_n / (n * f_1) = sqrt(1 + B * n^2)
    # So: (f_n / (n * f_1))^2 - 1 = B * n^2

    n_values = collect(1:length(harmonics))
    ratios = harmonics ./ (n_values .* fundamental)
    y = ratios.^2 .- 1
    x = n_values.^2

    # Linear regression through origin: y = B * x
    B = dot(x, y) / dot(x, x)
    return B
end

"""
Plot spectrum comparison for multiple files
"""
function plot_spectrum_comparison(files::Vector{String};
                                  title::String="Spectrum Comparison",
                                  max_freq::Float64=8000.0,
                                  output_file::String="")
    p = plot(title=title, xlabel="Frequency (Hz)", ylabel="Amplitude (dB)",
             xlims=(0, max_freq), ylims=(-80, 5), legend=:topright, size=(1000, 500))

    for filepath in files
        if !isfile(filepath)
            println("  Skipping missing file: $filepath")
            continue
        end

        samples, sr = load_wav(filepath)
        freqs, spectrum_db = compute_spectrum(samples, Float64(sr))

        # Get filename for legend
        label = basename(filepath)[1:end-4]  # Remove .wav

        # Downsample for plotting
        freq_mask = freqs .<= max_freq
        plot!(p, freqs[freq_mask], spectrum_db[freq_mask], label=label, linewidth=1.5)
    end

    if !isempty(output_file)
        savefig(p, output_file)
        println("  Saved: $output_file")
    end

    return p
end

"""
Plot harmonic deviation chart (shows inharmonicity visually)
"""
function plot_harmonic_deviation(filepath::String; fundamental::Float64=82.41,
                                  output_file::String="")
    if !isfile(filepath)
        println("  Missing: $filepath")
        return nothing
    end

    samples, sr = load_wav(filepath)
    freqs, spectrum_db = compute_spectrum(samples, Float64(sr))

    harmonics, amplitudes, deviations = find_harmonics(freqs, spectrum_db, fundamental)
    B = estimate_inharmonicity(harmonics, fundamental)

    title_text = "$(basename(filepath))\nInharmonicity B = $(round(B, digits=6))"

    p = bar(1:length(deviations), deviations,
            title=title_text,
            xlabel="Harmonic Number", ylabel="Deviation from Ideal (%)",
            legend=false, size=(800, 400), fillcolor=:steelblue)

    hline!(p, [0], color=:red, linestyle=:dash, linewidth=2)

    if !isempty(output_file)
        savefig(p, output_file)
        println("  Saved: $output_file")
    end

    return p, B, deviations
end

"""
Compute and plot spectrogram (time-frequency representation)
"""
function plot_spectrogram(filepath::String; max_freq::Float64=6000.0, output_file::String="")
    if !isfile(filepath)
        println("  Missing: $filepath")
        return nothing
    end

    samples, sr = load_wav(filepath)

    # Spectrogram parameters
    window_size = 2048
    hop_size = 512

    spec = spectrogram(samples, window_size, hop_size; fs=Int(sr), window=hanning)

    # Convert to dB
    power_db = 10 .* log10.(spec.power .+ 1e-10)

    # Limit frequency range
    freq_mask = spec.freq .<= max_freq

    p = heatmap(spec.time, spec.freq[freq_mask], power_db[freq_mask, :],
                title=basename(filepath),
                xlabel="Time (s)", ylabel="Frequency (Hz)",
                colorbar_title="Power (dB)", c=:viridis,
                size=(1000, 400))

    if !isempty(output_file)
        savefig(p, output_file)
        println("  Saved: $output_file")
    end

    return p
end

"""
Comprehensive analysis of a single oscillator file
"""
function analyze_file(filepath::String; fundamental::Float64=82.41)
    println("\n=== Analyzing: $(basename(filepath)) ===")

    if !isfile(filepath)
        println("  File not found!")
        return nothing
    end

    samples, sr = load_wav(filepath)
    println("  Duration: $(round(length(samples)/sr, digits=2))s, SR: $(Int(sr))Hz")

    freqs, spectrum_db = compute_spectrum(samples, Float64(sr))
    harmonics, amplitudes, deviations = find_harmonics(freqs, spectrum_db, fundamental)
    B = estimate_inharmonicity(harmonics, fundamental)

    println("  Detected harmonics: $(length(harmonics))")
    println("  Inharmonicity B: $(round(B, digits=6))")

    if length(deviations) > 0
        println("  Harmonic deviations (%):")
        for (i, dev) in enumerate(deviations[1:min(8, length(deviations))])
            println("    H$i: $(round(dev, digits=3))%")
        end
    end

    return Dict(
        :harmonics => harmonics,
        :amplitudes => amplitudes,
        :deviations => deviations,
        :inharmonicity_B => B
    )
end

# ============================================================================
# Main Analysis Functions
# ============================================================================

"""
Compare dispersion effects: harmonic vs stretched vs compressed
"""
function compare_dispersion()
    println("\n" * "="^60)
    println("DISPERSION COMPARISON: Harmonic vs Stretched vs Compressed")
    println("="^60)

    files = [
        joinpath(OUTPUT_DIR, "inharm_ref_harmonic.wav"),
        joinpath(OUTPUT_DIR, "inharm_mild_stretch.wav"),
        joinpath(OUTPUT_DIR, "inharm_strong_stretch.wav"),
        joinpath(OUTPUT_DIR, "inharm_mild_compress.wav"),
        joinpath(OUTPUT_DIR, "inharm_strong_compress.wav"),
    ]

    plot_spectrum_comparison(files,
        title="Dispersion Effect on Spectrum",
        output_file=joinpath(PLOT_DIR, "dispersion_comparison.png"))

    # Individual harmonic analysis
    for f in files
        if isfile(f)
            plot_harmonic_deviation(f, fundamental=82.41,
                output_file=joinpath(PLOT_DIR, "harmonics_$(basename(f)[1:end-4]).png"))
        end
    end
end

"""
Compare 1st-order vs 2nd-order APF
"""
function compare_apf_orders()
    println("\n" * "="^60)
    println("APF ORDER COMPARISON: 1st-order vs 2nd-order")
    println("="^60)

    files = [
        joinpath(OUTPUT_DIR, "inharm_cmp_1st_order.wav"),
        joinpath(OUTPUT_DIR, "inharm_cmp_2nd_order.wav"),
    ]

    plot_spectrum_comparison(files,
        title="1st-order vs 2nd-order APF Comparison",
        output_file=joinpath(PLOT_DIR, "apf_order_comparison.png"))
end

"""
Compare multi-stage effects
"""
function compare_stages()
    println("\n" * "="^60)
    println("MULTI-STAGE COMPARISON")
    println("="^60)

    files = [
        joinpath(OUTPUT_DIR, "inharmx_1stage.wav"),
        joinpath(OUTPUT_DIR, "inharmx_4stage.wav"),
        joinpath(OUTPUT_DIR, "inharmx_6stage.wav"),
    ]

    plot_spectrum_comparison(files,
        title="Multi-Stage APF: 1 vs 4 vs 6 Stages",
        output_file=joinpath(PLOT_DIR, "stages_comparison.png"))
end

"""
Compare Q values on 2nd-order APF
"""
function compare_q_values()
    println("\n" * "="^60)
    println("2ND-ORDER APF Q COMPARISON")
    println("="^60)

    files = [
        joinpath(OUTPUT_DIR, "inharm_biq_high_q.wav"),
        joinpath(OUTPUT_DIR, "inharm_biq_low_q.wav"),
    ]

    plot_spectrum_comparison(files,
        title="2nd-order APF: High Q vs Low Q",
        output_file=joinpath(PLOT_DIR, "q_comparison.png"))
end

"""
Compare multi-band emphasis settings
"""
function compare_multiband()
    println("\n" * "="^60)
    println("MULTI-BAND APF COMPARISON")
    println("="^60)

    files = [
        joinpath(OUTPUT_DIR, "inharm_mb_default.wav"),
        joinpath(OUTPUT_DIR, "inharm_mb_low.wav"),
        joinpath(OUTPUT_DIR, "inharm_mb_high.wav"),
    ]

    plot_spectrum_comparison(files,
        title="Multi-band APF: Default vs Low vs High Emphasis",
        output_file=joinpath(PLOT_DIR, "multiband_comparison.png"))
end

"""
Plot spectrograms for dynamic sweeps
"""
function analyze_sweeps()
    println("\n" * "="^60)
    println("SPECTROGRAM ANALYSIS OF SWEEPS")
    println("="^60)

    sweep_files = [
        "inharm_sweep_full.wav",
        "inharm_biq_fc_sweep.wav",
        "inharm_biq_q_sweep.wav",
        "inharmx_full.wav",
    ]

    for f in sweep_files
        filepath = joinpath(OUTPUT_DIR, f)
        if isfile(filepath)
            plot_spectrogram(filepath,
                output_file=joinpath(PLOT_DIR, "spectrogram_$(f[1:end-4]).png"))
        end
    end
end

"""
Comprehensive bell/bar/membrane comparison
"""
function compare_percussive()
    println("\n" * "="^60)
    println("PERCUSSIVE SOUNDS: Bell vs Bar vs Membrane")
    println("="^60)

    files = [
        joinpath(OUTPUT_DIR, "inharm_curved_bell.wav"),
        joinpath(OUTPUT_DIR, "inharm_curved_bar.wav"),
        joinpath(OUTPUT_DIR, "inharm_curved_membrane.wav"),
    ]

    plot_spectrum_comparison(files,
        title="Percussive Timbres: Bell, Bar, Membrane",
        max_freq=10000.0,
        output_file=joinpath(PLOT_DIR, "percussive_comparison.png"))

    # Analyze each for inharmonicity
    fundamentals = [261.63, 164.81, 110.0]  # C4, E3, A2
    for (f, fund) in zip(files, fundamentals)
        if isfile(f)
            analyze_file(f, fundamental=fund)
        end
    end
end

# ============================================================================
# Main Entry Point
# ============================================================================

function main()
    println("""
    ================================================================
                  INHARMONIC RPM SPECTRAL ANALYSIS
                         Julia Visualization
    ================================================================
    """)

    if length(ARGS) > 0
        # Analyze specific files
        for filepath in ARGS
            analyze_file(filepath)
            plot_spectrogram(filepath, output_file=joinpath(PLOT_DIR, "spec_$(basename(filepath)[1:end-4]).png"))
        end
    else
        # Run all comparisons
        compare_dispersion()
        compare_apf_orders()
        compare_stages()
        compare_q_values()
        compare_multiband()
        analyze_sweeps()
        compare_percussive()
    end

    println("\n" * "="^60)
    println("Analysis complete! Plots saved to: $PLOT_DIR")
    println("="^60)
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
