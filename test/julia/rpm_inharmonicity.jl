using DSP, FFTW, Plots
gr()

fs      = 48000.0
f0      = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 110.0
beta    = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 1.5
omega   = 2π * f0 / fs
N       = 16384
discard = 4096

sqr(y) = y * y

# =====================================================
# STABLE INHARMONIC RPM
# =====================================================
#
# Architecture:
# 1. Generate a "pilot" RPM oscillator at fundamental frequency
# 2. Use pilot's phase modulation (u) to modulate a bank of
#    inharmonic oscillators
# 3. Each partial h gets modulation h * u (standard FM ratio)
# 4. Partials stay at their stretched frequencies because
#    the feedback loop only involves the stable pilot
# =====================================================

# -----------------------------
# Method 1: Pilot-driven inharmonic bank
# Clean separation of RPM feedback from partial generation
# -----------------------------
function rpm_pilot_bank(omega, beta, N; alpha=0.001, B=0.0, num_partials=12)
    y = zeros(Float64, N)
    pilot = zeros(Float64, N)  # Reference oscillator
    rms_sq = 0.5
    pilot_phase = 0.0

    # Partial setup
    partial_omegas = zeros(Float64, num_partials)
    partial_phases = zeros(Float64, num_partials)
    partial_amps = zeros(Float64, num_partials)

    for h in 1:num_partials
        stretch = sqrt(1.0 + B * h * h)
        partial_omegas[h] = omega * h * stretch
        partial_amps[h] = 1.0 / h
    end
    partial_amps ./= sum(partial_amps)

    for n in 2:N
        n1, n2 = n-1, max(n-2, 1)

        # Pilot oscillator - standard RPM at fundamental
        pilot_tpt = 0.5 * (pilot[n1] + pilot[n2])
        pilot_sq = 0.5 * (sqr(pilot[n1]) + sqr(pilot[n2]))
        rms_sq += alpha * (pilot_sq - rms_sq)
        rms = sqrt(max(rms_sq, 0.01))

        # Phase modulation from pilot
        u = beta * pilot_tpt / rms

        # Advance pilot phase
        pilot_phase += omega
        pilot[n] = sin(pilot_phase + u)

        # Generate inharmonic partials using pilot's modulation
        out = 0.0
        for h in 1:num_partials
            partial_phases[h] += partial_omegas[h]
            # Each partial gets scaled modulation
            out += partial_amps[h] * sin(partial_phases[h] + h * u)
        end
        y[n] = out
    end
    y
end

# -----------------------------
# Method 2: Lowpass-filtered feedback bank
# Filter the mixed output to extract stable fundamental component
# for feedback, then modulate inharmonic partials
# -----------------------------
function rpm_lowpass_bank(omega, beta, N; alpha=0.001, B=0.0, num_partials=12, lp_freq=200.0)
    y = zeros(Float64, N)
    rms_sq = 0.5

    # Simple one-pole lowpass for feedback
    lp_coef = 1.0 - exp(-2π * lp_freq / fs)
    lp_state = 0.0

    # Partial setup
    partial_omegas = zeros(Float64, num_partials)
    partial_phases = zeros(Float64, num_partials)
    partial_amps = zeros(Float64, num_partials)

    for h in 1:num_partials
        stretch = sqrt(1.0 + B * h * h)
        partial_omegas[h] = omega * h * stretch
        partial_amps[h] = 1.0 / h
    end
    partial_amps ./= sum(partial_amps)

    for n in 2:N
        n1, n2 = n-1, max(n-2, 1)

        # Lowpass filter on output for stable feedback
        lp_state += lp_coef * (y[n1] - lp_state)
        lp_prev = if n > 2
            lp_state + lp_coef * (y[n2] - lp_state)
        else
            lp_state
        end

        # TPT on filtered signal
        y_tpt = 0.5 * (lp_state + lp_prev)
        ysq = 0.5 * (sqr(y[n1]) + sqr(y[n2]))
        rms_sq += alpha * (ysq - rms_sq)
        rms = sqrt(max(rms_sq, 0.01))

        u = beta * y_tpt / rms

        # Generate partials
        out = 0.0
        for h in 1:num_partials
            partial_phases[h] += partial_omegas[h]
            out += partial_amps[h] * sin(partial_phases[h] + h * u)
        end
        y[n] = out
    end
    y
end

# -----------------------------
# Method 3: Per-partial feedback with coupling
# Each partial has its own feedback loop, but partials
# are weakly coupled through the mixed output
# -----------------------------
function rpm_coupled_partials(omega, beta, N; alpha=0.001, B=0.0,
                              num_partials=8, coupling=0.1)
    y = zeros(Float64, N)

    partial_omegas = zeros(Float64, num_partials)
    partial_phases = zeros(Float64, num_partials)
    partial_amps = zeros(Float64, num_partials)
    partial_y = zeros(Float64, num_partials)
    partial_y_prev = zeros(Float64, num_partials)
    partial_rms = fill(0.5, num_partials)

    for h in 1:num_partials
        stretch = sqrt(1.0 + B * h * h)
        partial_omegas[h] = omega * h * stretch
        partial_amps[h] = 1.0 / h
    end
    partial_amps ./= sum(partial_amps)

    for n in 2:N
        n1, n2 = n-1, max(n-2, 1)

        # Global coupling term from previous mixed output
        global_coupling = coupling * y[n1]

        out = 0.0
        for h in 1:num_partials
            # Per-partial TPT feedback
            y_tpt = 0.5 * (partial_y[h] + partial_y_prev[h])
            ysq = partial_y[h] * partial_y[h]
            partial_rms[h] += alpha * (ysq - partial_rms[h])
            rms = sqrt(max(partial_rms[h], 0.01))

            # Modulation: self + weak coupling
            u_h = beta * (y_tpt / rms + global_coupling)

            partial_phases[h] += partial_omegas[h]
            new_y = sin(partial_phases[h] + u_h)

            partial_y_prev[h] = partial_y[h]
            partial_y[h] = new_y

            out += partial_amps[h] * new_y
        end
        y[n] = out
    end
    y
end

# -----------------------------
# Reference
# -----------------------------
function rpm_reference(omega, beta, N; alpha=0.001)
    y = zeros(Float64, N)
    rms_sq = 0.5
    phase = 0.0
    for n in 2:N
        phase += omega
        n1, n2 = n-1, max(n-2, 1)
        y_tpt = 0.5 * (y[n1] + y[n2])
        ysq_avg = 0.5 * (sqr(y[n1]) + sqr(y[n2]))
        rms_sq += alpha * (ysq_avg - rms_sq)
        rms = sqrt(max(rms_sq, 0.01))
        u = beta * y_tpt / rms
        y[n] = sin(phase + u)
    end
    y
end

# -----------------------------
# Analysis
# -----------------------------
function mag_spectrum(x)
    X = fft(x .* hann(length(x)))
    mag = abs.(X)[1:div(end,2)]
    mag ./ maximum(mag)
end

function find_peaks_near(spec, freqs, target_freqs; threshold_db=-50, window=30.0)
    db = 20 .* log10.(spec .+ 1e-12)
    results = []
    for (h, target) in enumerate(target_freqs)
        idx_range = findall(x -> abs(x - target) < window, freqs)
        if isempty(idx_range)
            push!(results, (h=h, target=target, actual=NaN, cents=NaN))
            continue
        end
        best_idx = idx_range[argmax(db[idx_range])]
        if db[best_idx] < threshold_db
            push!(results, (h=h, target=target, actual=NaN, cents=NaN))
            continue
        end
        actual = freqs[best_idx]
        cents = 1200 * log2(actual / target)
        push!(results, (h=h, target=target, actual=actual, cents=cents))
    end
    results
end

# -----------------------------
# Main
# -----------------------------
println("\nStable Inharmonic RPM Test")
println("==========================")
println("f0 = $f0 Hz, β = $beta")
println()

# Generate reference
y_ref = rpm_reference(omega, beta, N)[discard:end]
spec_ref = mag_spectrum(y_ref)
freqs = fs .* (0:length(spec_ref)-1) ./ length(y_ref)

println("Reference (standard RPM):")
harm_freqs = [h * f0 for h in 1:8]
peaks = find_peaks_near(spec_ref, freqs, harm_freqs)
for p in peaks
    if !isnan(p.actual)
        println("  H$(p.h): $(round(p.actual, digits=1)) Hz")
    end
end
println()

# Test pilot-driven approach
println("Method 1: Pilot-driven inharmonic bank")
println("======================================")
for B in [0.0, 0.001, 0.003]
    y = rpm_pilot_bank(omega, beta, N; B=B)[discard:end]
    spec = mag_spectrum(y)
    # Calculate expected stretched frequencies
    stretched = [h * f0 * sqrt(1.0 + B * h * h) for h in 1:8]
    peaks = find_peaks_near(spec, freqs, stretched)
    label = B > 0 ? "tight" : "harmonic"
    println("\nB = $B ($label):")
    print("  Target freqs: ")
    for h in 1:6
        print("$(round(stretched[h], digits=1)) ")
    end
    println()
    print("  Actual (¢ from target): ")
    for p in peaks[1:6]
        if !isnan(p.actual)
            print("$(round(p.cents, sigdigits=2))¢ ")
        else
            print("-- ")
        end
    end
    println()
end
println()

# Test lowpass approach
println("\nMethod 2: Lowpass-filtered feedback bank")
println("========================================")
for B in [0.001, 0.003]
    y = rpm_lowpass_bank(omega, beta, N; B=B, lp_freq=f0*1.5)[discard:end]
    spec = mag_spectrum(y)
    stretched = [h * f0 * sqrt(1.0 + B * h * h) for h in 1:8]
    peaks = find_peaks_near(spec, freqs, stretched)
    println("\nB = $B:")
    print("  Cents from target: ")
    for p in peaks[1:6]
        if !isnan(p.actual)
            print("$(round(p.cents, sigdigits=2))¢ ")
        else
            print("-- ")
        end
    end
    println()
end

# -----------------------------
# Plotting
# -----------------------------

# Calculate B=0.001 stretched frequencies for vertical lines
B_test = 0.001
stretched_001 = [h * f0 * sqrt(1.0 + B_test * h * h) for h in 1:10]

B_test2 = 0.003
stretched_003 = [h * f0 * sqrt(1.0 + B_test2 * h * h) for h in 1:10]

p1 = plot(
    title="Reference: Standard RPM (harmonic)",
    xlabel="Frequency (Hz)", ylabel="Magnitude (dB)",
    xlim=(0, f0 * 12), ylim=(-60, 0), legend=false
)
plot!(p1, freqs, 20 .* log10.(spec_ref .+ 1e-9), linewidth=1.5, color=:blue)
for h in 1:10
    vline!(p1, [h * f0], color=:red, alpha=0.3, linestyle=:dash)
end

p2 = plot(
    title="Pilot Bank: B=0.001 (tight)",
    xlabel="Frequency (Hz)", ylabel="Magnitude (dB)",
    xlim=(0, f0 * 12), ylim=(-60, 0), legend=false
)
y = rpm_pilot_bank(omega, beta, N; B=0.001)[discard:end]
spec = mag_spectrum(y)
plot!(p2, freqs, 20 .* log10.(spec .+ 1e-9), linewidth=1.5, color=:orange)
for (h, sf) in enumerate(stretched_001)
    vline!(p2, [sf], color=:purple, alpha=0.5, linestyle=:dash)
end
for h in 1:10
    vline!(p2, [h * f0], color=:gray, alpha=0.2, linestyle=:dot)
end

p3 = plot(
    title="Pilot Bank: B=0.003 (very tight)",
    xlabel="Frequency (Hz)", ylabel="Magnitude (dB)",
    xlim=(0, f0 * 12), ylim=(-60, 0), legend=false
)
y = rpm_pilot_bank(omega, beta, N; B=0.003)[discard:end]
spec = mag_spectrum(y)
plot!(p3, freqs, 20 .* log10.(spec .+ 1e-9), linewidth=1.5, color=:red)
for (h, sf) in enumerate(stretched_003)
    vline!(p3, [sf], color=:purple, alpha=0.5, linestyle=:dash)
end
for h in 1:10
    vline!(p3, [h * f0], color=:gray, alpha=0.2, linestyle=:dot)
end

p4 = plot(
    title="Pilot Bank: B=-0.001 (loose)",
    xlabel="Frequency (Hz)", ylabel="Magnitude (dB)",
    xlim=(0, f0 * 12), ylim=(-60, 0), legend=false
)
B_neg = -0.001
stretched_neg = [h * f0 * sqrt(max(0.1, 1.0 + B_neg * h * h)) for h in 1:10]
y = rpm_pilot_bank(omega, beta, N; B=B_neg)[discard:end]
spec = mag_spectrum(y)
plot!(p4, freqs, 20 .* log10.(spec .+ 1e-9), linewidth=1.5, color=:green)
for (h, sf) in enumerate(stretched_neg)
    vline!(p4, [sf], color=:purple, alpha=0.5, linestyle=:dash)
end
for h in 1:10
    vline!(p4, [h * f0], color=:gray, alpha=0.2, linestyle=:dot)
end

final_plot = plot(p1, p2, p3, p4, layout=(2, 2), size=(1400, 900))

outfile = tempname() * "_rpm_stable_inharmonic.png"
savefig(final_plot, outfile)
run(`open $outfile`)

println("\n\nImage saved to: $outfile")
println()
println("Purple dashed = inharmonic target, Gray dotted = harmonic grid")
println()
println("Usage: julia rpm_inharmonicity.jl [f0] [beta]")
