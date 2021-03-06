function [ args stim ] = parameter_file
% For calibration, change args.par_vals to [ -6 -6 -6] and change
% stim.stim_duration to 5.0.

% 9/18/2012 - changed args.intensity to .015, following FDL-in-noise
% calibrations.  -4 dB E/No should have no peak clipping. Max tone level
% will be 60 dB SPL.

args =struct('method','mcs', ...    Define parameters
    'block_number'      , []  , ...
    'AM'                , 20  , ...  % AM rate in Hz
    'duration'          , 2   , ...  % stimulus duration in seconds
    'frequency'         , 1000, ...
    'intensity'         , 0.015, ... .3 keeps max(abs(noise)) < 1.0;   %% 6/12/2012 changed from .225 to 0.09 same as FDL in noise task.
    'isi'               , 0.3 , ...
    'par_vals'          , [0 10 20 30 40 60], ...  % delta f from 'frequency'
    'n_trialsperstim'   ,   2, ...  % 10refers to signal+noise trials, this same amount for catch trials
    'order'             ,   [], ...
    'path'              , 'C:\Users\cwbishop\Documents\Projects\FFR\', ...
    'psych_point'       , 0.91, ...
    'samprate'          ,44100, ...
    'subject_id'        ,   [], ...
    'trials'            ,   [], ...
    'trial_display'     ,    1, ... == 1 shows trial info at commmand line
    'warn_subject'      ,    1);  %warn_subject == 1 alerts subject to upcoming trial

stim = struct( ...              % Define stimulus parameters
    'samprate'          , 44100, ... sampling frequency
    'rise_fall_time'    , 0.020, ... rise/fall time in seconds
    'stim_duration'     ,  0.3 );  %  Stimulus duration in seconds 0.3