function [PLV, FOUT, PLVOUT]=AA_phasecoher(ERPF, FRANGE, CHANS, NSEM, BINS, PLEV, TFREQS)
%% DESCRIPTION:%
%
%   Extract data and compute phase coherence values within and across
%   listeners.
%
% INPUT:
%
%   ERPF:   cell array, each member is the full path to either an ERP data
%           structure, which will then be dereferenced to the original EEG
%           dataset, or an EEG dataset structure. For the former to work,
%           the ERP and EEG datasets must exist in the same directory. If
%           this isn't the case, then proceed with extreme caution.
%
%           Alternatively, ERPF can be an EEG structure array. 
%
%           Regardless of the method employed, the ultimate EEG structure
%           MUST contain the EVENTLIST field generated by ERPLAB. If it
%           doesn't, things won't work properly or not at all (more likely
%           the latter). 
%
%   CHANS:  integer array, channels to compute phase coherence on.
%           (default=1). (Currently untested with multiple channels)
%   ...
%
% OUTPUT:
%
%
% NOTE: Keep in mind the PLVs are biased by the number of trials used to
%       estimate them: PLVs tend to be larger with low trial numbers. So
%       comparing across subjects/conditions is a non-trivial issue unless
%       a corrective factor is applied. CWB is not aware of any validated
%       corrective factor. One attempt does exist in the literature (see
%       Backer, Hill, Shahin, Miller J Neurosci (2010) and Shahin et al. J
%       Neurphysiol (2010)), but the corrective factor applied (converting
%       to Rayleigh's Z) does not remove the trial bias effects. So this
%       method should NOT be applied to these or any other PLV data.
%
% Christopher W. Bishop
%   University of Washington 
%   12/13

%% DEFAULTS
%   Defaults set based on needs of AA02.
if ~exist('PLEV', 'var') || isempty(PLEV), PLEV=1; end
if ~exist('NSEM', 'var') || isempty(NSEM), NSEM=0; end % 0 by default
if ~exist('TFREQS', 'var'), TFREQS=[]; end % empty by default
if ~exist('CHANS', 'var') || isempty(CHANS), CHANS=1; end % just one channel by default
if ~exist('FRANGE', 'var'), FRANGE=[]; end 

%% OUTPUTS
FOUT=[];    % frequencies corresponding to TFREQS
PLVOUT=[];  % PLVs for specific target frequencies. 
PLV=[];     % Phase locking values (PLVs) for each channel, frequency, BIN, and subject.
            %   So this should be a CxFxBxS array - rather complicated, eh?

%% LOOP THROUGH ERPFILES
for s=1:length(ERPF)
    
    %% TRY TO LOAD THE EEG DATASET
    %   Ultimately this section will generate a variable, EEG, that we will
    %   then operate on in the remainded of the code.
    if iscell(ERPF) && ischar(ERPF{s})
        
        % First, if the input is a string (presumably a file path), then
        % try loading the file. Check to see if it's a full path to an EEG
        % data set. If not, assume it's an ERP structure and work backwards
        % to the EEG data set.
        [pathstr,name,ext]= fileparts(ERPF{s});
        try 
            EEG=pop_loadset([name ext], pathstr); 
        catch
        
            % Load the ERP file
            ERP=pop_loaderp('filename', [name ext], 'filepath', pathstr);
        
            % A couple of sanity checks to protect Chris in the future
            if length(ERP.workfiles)>1
                error('AA_phasecoher:MultipleWorkFiles',...
                    ['There appear to be more than one workfile, which this code does not know how to deal with yet.' ...
                    '\nTime to reconsider your options.']);
            end % if length(ERP...
        
            % Load the original work file
            EEG=pop_loadset(ERP.workfiles{1}, ERP.filepath);
        end % try catch
    else
        % Otherwise, assume the user has passed in an array of EEG
        % structures, one for each subject. Grab the correct structure and
        % move on. 
        EEG=ERPF(s);
    end % if ischar
    
    %% SET DEFAULT FOR NUMBER OF BINS
    %   Set to the length of the bin descriptor file (BDF) unless specified
    %   otherwise.
    if ~exist('BINS', 'var') || isempty(BINS)
        BINS=1:length(EEG.EVENTLIST.bdf);
    end % if ~exist('BINS'...
    
    %% GET SAMPLING RATE
    FS=EEG.srate;
    
    %% LOOP THROUGH BINS    
    for b=1:length(BINS)        
        
        %% GRAB BIN LABEL
        %   Assumes that ERPLAB copied the EVENTLIST back to EEG structure
        %   at some point.
        LABELS{b}=EEG.EVENTLIST.bdf(b).description;
        
        %% CREATE TIME MASK
        %   Only look at post stimulus period, ignore all prestim stuff.
        TMASK=find(EEG.times>=0, 1, 'first'):length(EEG.times); % post-stim mask.
        
        %% GRAB SWEEPS
        %   Use custom function, erplab_getsweeps, to grab the sweeps used
        %   by ERPLAB to generate bin averages. Only grabs the "good"
        %   sweeps. 
        SWEEPS=erplab_getsweeps(EEG, BINS(b), 1);
        
        %% APPLY CHANNEL AND TIME MASK
        SWEEPS=SWEEPS(CHANS, TMASK, :);
        
        %% FFT VARIABLE
        Y=[];
        
        %% COMPUTE PLVs FOR EACH CHANNEL AND SWEEP
        for c=1:size(SWEEPS,1)
            
            %% FFT VARIABLES
            L=size(SWEEPS,2);
            NFFT=L;    
            f = FS/2*linspace(0,1,NFFT/2+1);
            
            %% VARIABLES TO TRACK THE SUM OF SIN AND COS
            %   Track SUMSIN/SUMCOS for each channel and frequency bin.
            %   Must be zeroed out for each channel and BIN.        
            SUMSIN=zeros(1,length(f));
            SUMCOS=zeros(1,length(f));
            
            % Loop through channels
            for t=1:size(SWEEPS,3)
                % Loop through sweeps
                
                % Reduce data dimensions
                y=squeeze(SWEEPS(c,:,t));
                
                % Compute FFT for each sweep
                Y=fft(y,NFFT)/NFFT;                
               
                % Only want to look at positive frequencies
                %   PLVs will be symmetric about the Nyquist, so we'll just
                %   look at the positive frequencies to save space and
                %   CWB's brain.
                Y=Y(1:NFFT/2+1); 
                
                % Convert to something useful for PLV calculation
                %   1. Convert to just an ANGLE measure
                %   2. Add sin
                %   3. Add cos
                Y=angle(Y); 
                SUMSIN=SUMSIN + sin(Y);
                SUMCOS=SUMCOS + cos(Y);                
            end % t=1:size(SWEEPS,3), number of sweeps
            
            %% COMPUTE PHASE COHERENCE (PLV)
            %   Followed suggestions and equations in 
            %
            %   Picton, T. W., et al. (2003). "Human auditory steady-state responses." Int J Audiol 42(4): 177-219.
            %   (See page 183)
            %
            %   PLV is CxFxBxS
            %   Divide by number of sweeps, which normalizes vector length
            %   to within [0 1]
            PLV(c,:,b,s)=(sqrt(SUMSIN.^2 + SUMCOS.^2))./size(SWEEPS,3);
            
            %% SANITY CHECK PLVs
            %   PLVs should range from [0 1]. If they don't, then something
            %   is wrong. Quick sanity check just in case something wonky
            %   happens in the future.
            if ~isempty(find(PLV(c,:,b,s)<0 || PLV(c,:,b,s)>1, 1))
                error('AA_phasecoher:PhaseOutofRange', ...
                    'Vector length is outside the expected range.');
            end % ~isempty(find( ...
            
            %% GET Target FREQuencies (TFREQS)
            %   Helpful to remove specific frequencies user is interested
            %   in for streamlined analyses later.
            for z=1:length(TFREQS)
                % Find index of target frequency
                %   Look for an exact match first
                ind=find(f==TFREQS(z));
            
                % Error checking - make sure we find the precise frequency. If
                % not, throw an error.
                %
                % Changed to warning because there seems to be some rounding
                % error or something (on the order of 10^-13) at some
                % frequencies that is preventing a perfect match. So, we'll go
                % with the 
                if isempty(ind)
                    tmp=abs(f-TFREQS(z));
                    ind= (tmp==min(tmp));
                    warning('AA_phasecoher:NoExactMatch', [num2str(TFREQS(z)) ' not found!\nClosest frequency is ' num2str(f(ind)) ' Hz. \n\nProceeding with closest frequency. \n\nSee FOUT for exact frequencies.']);                 
                end % if isempty(ind)
                
                % Grab frequency and PLV
                FOUT(z)=f(ind); 
                PLVOUT(c,z,b,s)=PLV(c,ind,b,s); 
            end % z=1:length(TFREQS)
        end % i=1:size(SWEEPS,1), number of channels
    end % b=1:length(BINS)
end % s=1:length(ERPF)

%% PLOTTING ROUTINES
%   Generate plots to help visualize the data.

% First, get color scheme to match ERPLAB plotting.
[colorDef, styleDef]=erplab_linespec(max(BINS));

if PLEV>0
    
    %% MEAN PLV vs FREQUENCY
    %   Separate plot for each channel. Using subplot would be smarter, but
    %   I can't figure out how to make the axes expand when I click on the
    %   individual plots. ERPLAB does this, though, so I know it's
    %   possible.
    
    % First, plot the error bars.
    %   Yes, I know I'm looping through my data twice - it makes my life
    %   easier in the long run. Don't judge me.
    for c=1:size(PLV,1)        
        % Store handle for figure.
        h(c)=figure; 
        hold on
        for b=1:size(PLV,3)            
            % Grab raw data
            tdata=squeeze(PLV(c,:,b,:));
            
            % Plot standard error if user asks for it
            %   But only if there are at least two subjects
            if NSEM~=0 && size(tdata,2)>1
                % Compute +/-NSEM SEM
                U=mean(tdata,2) + std(tdata,0,2)./sqrt(size(tdata,2)).*NSEM; 
                L=mean(tdata,2) - std(tdata,0,2)./sqrt(size(tdata,2)).*NSEM; 
                ciplot(L, U, f, colorDef{BINS(b)}, 0.15);             
            end % if NSEM~=0            
        end % b=1:size(PLV,3)
    end % c=1:size(PLV,1)
    
    % Second, plot the mean data
    for c=1:size(PLV,1)
        % Get back to the correct figure
        figure(h(c)); 
        for b=1:size(PLV,3)
            
            % Grab raw data
            tdata=squeeze(PLV(c,:,b,:));
            
            % Find mean across subjects
            tdata=mean(tdata,2);
            
            % Plot mean series for this channel/bin
            plot(f, tdata, 'Color', colorDef{BINS(b)}, 'LineStyle', styleDef{BINS(b)}, 'linewidth', 1.5);
            
        end % b=1:size(PLV,3)
    end % c=1:size(PLV,1)
    
    %% MARKUP FIGURE
    xlabel('Frequency (Hz)')
    ylabel('PLV')
    legend(LABELS, 'Location', 'Best'); 
    title(['N=' num2str(length(ERPF)) ' | Bins: [' num2str(BINS) ']']); 

    % Set domain if user specifies it
    if exist('FRANGE', 'var') && ~isempty(FRANGE)
        xlim(FRANGE);
    end %
    
end % if PLEV>0
