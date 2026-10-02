%% DSP Lab - Group 3 - Data Plotting Script
% Creates the time-domain, frequency-domain and Nyquist-diagram plots for
% the lab data files.
%
% HOW TO RUN:
%   Put this m-file in the same folder as the .txt data files
%   ("DSP Group 3 Data") and run it. The script only looks for data in the
%   folder it lives in (or the current folder if run section-by-section).
%
% CURRENT SCOPE:
%   Experiment 4.1.11 Baseline - every .txt file whose name begins with
%   "4-1-11" (this also catches "4-1-11b..."). One figure is made per file,
%   with the time domain, frequency domain and Nyquist diagram as subplots.

clear; clc; close all;

%% ------------------------- USER SETTINGS --------------------------------
% Start of the file names to plot. Dashes also match "_", "." or spaces, so
% '4-1-11' finds "4-1-11.txt", "4-1-11b.txt", "4_1_11 trial 2.txt", etc.
FILE_PREFIX = '4-1-11';

% File types counted as data (Excel, PDF, m-files etc. are ignored)
DATA_EXTENSIONS = {'.txt', '.lvm', '.dat', '.csv'};

% Sampling frequency [Hz]. Only used if the file has NO time column and the
% header does not state a sample rate / dt. Leave [] to be warned instead.
DEFAULT_FS = [];

% Actual (input) signal frequency [Hz] for the Nyquist diagram. Leave []
% to use the strongest measured peak. For aliased tests later on, set this
% to the frequency you set on the function generator.
TRUE_SIGNAL_FREQ = [];

% Time window shown on the time-domain plot [s]. Leave [] to auto-show
% about NUM_PERIODS_SHOWN periods of the dominant frequency.
TIME_WINDOW       = [];
NUM_PERIODS_SHOWN = 5;

% Peak detection for the frequency plot / Nyquist diagram
MAX_PEAKS      = 5;     % max number of peaks to label
PEAK_THRESHOLD = 0.10;  % peaks must be >= this fraction of the largest peak

% Print every data point to the command window (required by the worksheet)
PRINT_RAW_DATA = true;

%% --------------------------- FIND FILES ---------------------------------
dataFolder = fileparts(mfilename('fullpath'));
if isempty(dataFolder)
    dataFolder = pwd;
end

files = findDataFiles(dataFolder, FILE_PREFIX, DATA_EXTENSIONS);
if isempty(files)
    % Show what IS in the folder, then let the user pick the right one
    listFolderContents(dataFolder);
    fprintf('\nNo data files starting with "%s" in:\n  %s\n', FILE_PREFIX, dataFolder);
    fprintf('Please select the folder that holds the data files...\n');
    picked = uigetdir(pwd, sprintf('Select the folder with the %s data files', FILE_PREFIX));
    if isequal(picked, 0)
        error('No folder selected.');
    end
    dataFolder = picked;
    files = findDataFiles(dataFolder, FILE_PREFIX, DATA_EXTENSIONS);
    if isempty(files)
        listFolderContents(dataFolder);
        error('Still no data files starting with "%s" in:\n  %s', FILE_PREFIX, dataFolder);
    end
end

fprintf('Data folder: %s\n', dataFolder);
fprintf('Found %d file(s) starting with "%s":\n', numel(files), FILE_PREFIX);
fprintf('  %s\n', files.name);

%% ------------------------ PROCESS EACH FILE -----------------------------
for k = 1:numel(files)
    fileName = files(k).name;
    [~, testName] = fileparts(fileName);

    % ---- Load data ----
    [t, v, fs, chanNames] = loadLabData(fullfile(files(k).folder, fileName), DEFAULT_FS);
    N = size(v, 1);

    % ---- Single-sided amplitude spectrum ----
    [f, A] = amplitudeSpectrum(v, fs);

    % ---- Prominent peaks (from first channel) ----
    [pkFreq, pkAmp] = findSpectrumPeaks(f, A(:, 1), MAX_PEAKS, PEAK_THRESHOLD);

    if isempty(TRUE_SIGNAL_FREQ)
        fSignal = pkFreq(1);
    else
        fSignal = TRUE_SIGNAL_FREQ;
    end

    % ---- Print data to command window ----
    fprintf('\n==================== %s ====================\n', fileName);
    fprintf('Number of samples (N)        : %d\n', N);
    fprintf('Sampling frequency (fs)      : %.4f Hz\n', fs);
    fprintf('Nyquist frequency (fs/2)     : %.4f Hz\n', fs/2);
    fprintf('Frequency resolution (fs/N)  : %.4f Hz\n', fs/N);
    for c = 1:size(v, 2)
        fprintf('%s: min = %.4f V, max = %.4f V, mean = %.4f V, Vpp = %.4f V\n', ...
            chanNames{c}, min(v(:,c)), max(v(:,c)), mean(v(:,c)), max(v(:,c)) - min(v(:,c)));
    end
    fprintf('Prominent frequency peaks (%s):\n', chanNames{1});
    fprintf('   Frequency [Hz]   Amplitude [V]\n');
    fprintf('   %12.4f   %13.4f\n', [pkFreq(:) pkAmp(:)].');
    fprintf('Signal frequency used for Nyquist diagram: %.4f Hz\n', fSignal);
    fprintf('Apparent (folded) frequency: %.4f Hz\n', foldFrequency(fSignal, fs));

    if PRINT_RAW_DATA
        fprintf('\nRaw data for %s:\n', fileName);
        rawTable = array2table([t v], 'VariableNames', ...
            matlab.lang.makeValidName([{'Time_s'} chanNames]));
        disp(rawTable);
    end

    % ---- Plot ----
    fig = figure('Name', testName, 'Color', 'w', 'Position', [100 100 900 900]);

    % Time domain
    subplot(3, 1, 1);
    plot(t, v, '-', 'LineWidth', 1);
    grid on;
    xlabel('Time [s]');
    ylabel('Voltage [V]');
    title(sprintf('Time Domain - %s', testName), 'Interpreter', 'none');
    if isempty(TIME_WINDOW)
        tEnd = min(t(end), t(1) + NUM_PERIODS_SHOWN / fSignal);
        xlim([t(1) tEnd]);
    else
        xlim(TIME_WINDOW);
    end
    if size(v, 2) > 1
        legend(chanNames, 'Interpreter', 'none', 'Location', 'best');
    end

    % Frequency domain (full spectrum, 0 to fs/2)
    subplot(3, 1, 2);
    plot(f, A, '-', 'LineWidth', 1);
    hold on;
    plot(pkFreq, pkAmp, 'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 7);
    for p = 1:numel(pkFreq)
        text(pkFreq(p), pkAmp(p), sprintf('  %.1f Hz', pkFreq(p)), ...
            'VerticalAlignment', 'bottom', 'FontSize', 9);
    end
    hold off;
    grid on;
    xlim([0 fs/2]);
    xlabel('Frequency [Hz]');
    ylabel('Amplitude [V]');
    title(sprintf('Frequency Domain - %s', testName), 'Interpreter', 'none');
    if size(v, 2) > 1
        legend([chanNames {'Peaks'}], 'Interpreter', 'none', 'Location', 'best');
    end

    % Nyquist diagram
    subplot(3, 1, 3);
    plotNyquistDiagram(fs, fSignal, pkFreq);
    title(sprintf('Nyquist Diagram - %s', testName), 'Interpreter', 'none');
end

%% ======================== LOCAL FUNCTIONS ===============================

function files = findDataFiles(folder, prefix, exts)
% Finds data files (this folder and its subfolders) whose names start with
% the prefix. Dashes in the prefix also match "_", "." or a space.
    files = listAllFiles(folder);
    pat   = ['^' regexprep(prefix, '[-_. ]', '[-_. ]?')];
    keep  = false(size(files));
    for i = 1:numel(files)
        [~, ~, ext] = fileparts(files(i).name);
        keep(i) = any(strcmpi(ext, exts)) && ...
                  ~isempty(regexpi(strtrim(files(i).name), pat, 'once'));
    end
    files = files(keep);
end

function files = listAllFiles(folder)
% All files in the folder and its subfolders (no duplicates).
    files = [dir(fullfile(folder, '*')); dir(fullfile(folder, '**', '*'))];
    files = files(~[files.isdir]);
    [~, iu] = unique(fullfile({files.folder}, {files.name}), 'stable');
    files = files(iu);
end

function listFolderContents(folder)
% Prints every file in the folder (and subfolders) to help find the data.
    items = listAllFiles(folder);
    fprintf('\nFiles in %s:\n', folder);
    if isempty(items)
        fprintf('  (folder is empty)\n');
    end
    for i = 1:numel(items)
        fprintf('  %s\n', fullfile(strrep(items(i).folder, folder, '.'), items(i).name));
    end
end

function [t, v, fs, chanNames] = loadLabData(filePath, defaultFs)
% Reads a text data file. Header/text lines are skipped; numeric rows are
% kept. If the first column is evenly spaced and increasing it is treated
% as time, otherwise all columns are treated as voltage channels.
    txt   = fileread(filePath);
    lines = regexp(txt, '\r?\n', 'split');

    rows    = {};
    nCols   = [];
    header  = {};
    for i = 1:numel(lines)
        ln = strtrim(lines{i});
        if isempty(ln)
            continue;
        end
        tok  = regexp(ln, '[\s,;]+', 'split');
        tok  = tok(~cellfun(@isempty, tok));
        vals = str2double(tok);
        if ~isempty(vals) && all(~isnan(vals))
            rows{end+1}  = vals;           %#ok<AGROW>
            nCols(end+1) = numel(vals);    %#ok<AGROW>
        elseif isempty(rows)
            header{end+1} = ln;            %#ok<AGROW>
        end
    end
    if isempty(rows)
        error('No numeric data found in %s', filePath);
    end

    % Keep only rows with the most common number of columns
    nMode = mode(nCols);
    data  = vertcat(rows{nCols == nMode});

    % Column names from the last header line, if it has the right count
    colNames = {};
    if ~isempty(header)
        hTok = regexp(header{end}, '\t|,|;|\s{2,}', 'split');
        hTok = strtrim(hTok(~cellfun(@isempty, strtrim(hTok))));
        if numel(hTok) == nMode
            colNames = hTok;
        end
    end

    % Is the first column time?
    hasTime = false;
    if nMode >= 2
        d = diff(data(:, 1));
        hasTime = all(d > 0) && (max(d) - min(d)) < 0.01 * mean(d);
    end

    if hasTime
        t  = data(:, 1);
        v  = data(:, 2:end);
        fs = 1 / mean(diff(t));
        if ~isempty(colNames), colNames = colNames(2:end); end
    else
        v  = data;
        fs = fsFromHeader(header);
        if isempty(fs)
            fs = defaultFs;
        end
        if isempty(fs)
            error(['%s has no time column and no sample rate in its header.\n' ...
                   'Set DEFAULT_FS in the USER SETTINGS section.'], filePath);
        end
        t = (0:size(v, 1) - 1).' / fs;
    end

    if isempty(colNames)
        colNames = arrayfun(@(c) sprintf('Channel %d', c), 1:size(v, 2), ...
            'UniformOutput', false);
    end
    chanNames = colNames;
end

function fs = fsFromHeader(header)
% Looks for a sample rate or dt in the header lines (e.g. LabVIEW files).
    fs  = [];
    num = '([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)';
    for i = 1:numel(header)
        h = lower(header{i});
        m = regexp(h, ['(?:sampl\w*\s*(?:rate|freq\w*)|fs)\D*?' num], 'tokens', 'once');
        if ~isempty(m)
            fs = str2double(m{1});
            if ~isempty(strfind(h, 'khz')), fs = fs * 1e3; end
            return;
        end
        m = regexp(h, ['(?:delta[_ ]?x|dt)\D*?' num], 'tokens', 'once');
        if ~isempty(m)
            fs = 1 / str2double(m{1});
            return;
        end
    end
end

function [f, A] = amplitudeSpectrum(v, fs)
% Single-sided amplitude spectrum (peak amplitude, in volts).
    N  = size(v, 1);
    Y  = fft(v);
    P2 = abs(Y) / N;
    nHalf = floor(N/2) + 1;
    A  = P2(1:nHalf, :);
    if mod(N, 2) == 0
        A(2:end-1, :) = 2 * A(2:end-1, :);
    else
        A(2:end, :) = 2 * A(2:end, :);
    end
    f = (0:nHalf - 1).' * fs / N;
end

function [pkFreq, pkAmp] = findSpectrumPeaks(f, A, maxPeaks, threshold)
% Simple peak finder (no Signal Processing Toolbox needed). Ignores DC.
    A = A(:); f = f(:);
    isPk = [false; A(2:end-1) > A(1:end-2) & A(2:end-1) >= A(3:end); false];
    isPk(1:2) = false;                        % skip DC and first bin
    idx = find(isPk & A >= threshold * max(A(3:end)));
    [~, order] = sort(A(idx), 'descend');
    idx = idx(order(1:min(maxPeaks, numel(order))));
    if isempty(idx)
        [~, idx] = max(A(3:end));
        idx = idx + 2;
    end
    pkFreq = f(idx);
    pkAmp  = A(idx);
end

function fa = foldFrequency(f, fs)
% Apparent frequency after sampling at fs (folds into 0..fs/2).
    fa = abs(f - fs * round(f / fs));
end

function plotNyquistDiagram(fs, fSignal, pkFreq)
% Folding diagram: apparent frequency vs actual frequency. The actual
% signal frequency and the measured peaks are marked with symbols.
    fN   = fs / 2;
    nFold = max(2, ceil(max([fSignal; pkFreq(:)]) / fN) + 1);
    fx   = linspace(0, nFold * fN, 2000 * nFold);
    plot(fx, foldFrequency(fx, fs), 'k-', 'LineWidth', 1.2);
    hold on;

    % Fold lines at multiples of fs/2
    for m = 1:nFold
        plot([m m] * fN, [0 fN], 'k:', 'HandleVisibility', 'off');
    end

    % Actual signal frequency and where it appears
    fApp = foldFrequency(fSignal, fs);
    plot(fSignal, fApp, 'ro', 'MarkerSize', 9, 'MarkerFaceColor', 'r');
    plot([fSignal fSignal], [0 fApp], 'r--', 'HandleVisibility', 'off');
    plot([0 fSignal], [fApp fApp], 'r--', 'HandleVisibility', 'off');

    % If aliased, also mark where it "falls down" to in the 0..fs/2 band
    isAliased = abs(fSignal - fApp) > fs * 1e-3;
    if isAliased
        plot(fApp, fApp, 'r^', 'MarkerSize', 9, 'MarkerFaceColor', 'y');
    end

    % Other measured peaks (shown in the 0..fs/2 band)
    others = pkFreq(abs(pkFreq - fApp) > fs * 1e-3);
    if ~isempty(others)
        plot(others, others, 'bs', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
    end
    hold off;

    grid on;
    xlim([0 nFold * fN]);
    ylim([0 1.1 * fN]);
    set(gca, 'XTick', (0:nFold) * fN);
    xlabel('Actual Frequency [Hz]  (ticks at multiples of f_s/2)');
    ylabel('Apparent Frequency [Hz]');
    lgd = {sprintf('Folding line (f_s = %.0f Hz)', fs), ...
           sprintf('Signal: %.1f Hz \\rightarrow appears at %.1f Hz', fSignal, fApp)};
    if isAliased
        lgd{end+1} = sprintf('Apparent (aliased) frequency: %.1f Hz', fApp);
    end
    if ~isempty(others)
        lgd{end+1} = 'Other measured peaks';
    end
    legend(lgd, 'Location', 'northeast');
end
