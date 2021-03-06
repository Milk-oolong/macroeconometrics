function [IRFINF,IRFSUP,IRFMED,IRFBAR] = IRFband(StructMod,opt)
% =======================================================================
% Calculate confidence intervals for impulse response functions computed
% with VARir
% =======================================================================
% [INF,SUP,MED,BAR] = VARirband(VAR,VARopt)
% -----------------------------------------------------------------------
% INPUTS 
%   - VAR: structure, result of VARmodel -> VARir function
%   - VARopt: options of the VAR (see VARopt from VARmodel)
% -----------------------------------------------------------------------
% OUTPUT
%   - INF(t,j,k): lower confidence band (t steps, j variable, k shock)
%   - SUP(t,j,k): upper confidence band (t steps, j variable, k shock)
%   - MED(t,j,k): median response (t steps, j variable, k shock)
%   - BAR(t,j,k): mean response (t steps, j variable, k shock)
% =======================================================================
% Ambrogio Cesa Bianchi, March 2015. Modified: August 2015
% ambrogio.cesabianchi@gmail.com

% I thank Andrey Zubarev for finding a bug in STEP 2.1 and 2.2 for the 
% case of nvar_ex~=0 and nlag_ex>0. 

% I thank Luca Rossi for finding a bug in STEP 3 for the case of nvar_ex~=0 
% and nlag_ex>0. 


%% Check inputs
%===============================================
%% Retrieve and initialize variables 
%===============================================
nsteps   = opt.nsteps;
ndraws   = opt.ndraws;
pctg     = opt.pctg;
method   = opt.method;
nvars    = size(StructMod.ENDO,2);
nvars_ex = size(StructMod.EXOG,2);
nlag     = opt.nlag;
nlag_ex  = opt.nlag_ex;
const    = opt.const;

nobs     = StructMod.nobs;
ENDO     = StructMod.ENDO;
EXOG     = StructMod.EXOG;
AMATt    = StructMod.AMATt;  % rows are coefficients, columns are equations
resid    = StructMod.residuals;

IRFINF = zeros(nsteps,nvars,nvars);
IRFSUP = zeros(nsteps,nvars,nvars);
IRFMED = zeros(nsteps,nvars,nvars);
IRFBAR = zeros(nsteps,nvars,nvars);

%% Create the matrices for the loop
%===============================================
y_artificial = zeros(nobs+nlag,nvars);
IRFpoint = nan(nsteps,nvars,nvars,ndraws);


%% Loop over the number of draws
%===============================================

tt = 1; % numbers of accepted draws
ww = 1; % index for printing on screen
while tt<=ndraws
    
    % Display number of loops
    if tt==10*ww
        disp(['Loop ' num2str(tt) ' / ' num2str(ndraws) ' draws'])
        ww=ww+1;
    end

%% STEP 1: choose the method and generate the residuals
    if strcmp(method,'bs')
        % Use the residuals to bootstrap: generate a random number bounded 
        % between 0 and # of residuals, then use the ceil function to select 
        % that row of the residuals (this is equivalent to sampling with replacement)
        u = resid(ceil(size(resid,1)*rand(nobs,1)),:);
    elseif strcmp(method,'wild')
        % Wild bootstrap based on simple distribution (~Rademacher)
        rr = 1-2*(rand(nobs,1)>0.5);
        u = resid.*(rr*ones(1,nvars));
    else
        error(['The method ' method ' is not available'])
    end

%% STEP 2: generate the artificial data

    %% STEP 2.1: initial values for the artificial data
    % Intialize the first nlag observations with real data
    LAG=[];
    for jj = 1:nlag
        y_artificial(jj,:) = ENDO(jj,:);
        LAG = [y_artificial(jj,:) LAG]; 
    end
    % Initialize the artificial series and the LAGplus vector
    T = [1:nobs]';
    if const==0
        LAGplus = LAG;
    elseif const==1
        LAGplus = [1 LAG];
    elseif const==2
        LAGplus = [1 T(1) LAG]; 
    elseif const==3
        T = [1:nobs]';
        LAGplus = [1 T(1) T(1).^2 LAG];
    end
    if nvars_ex~=0
        LAGplus = [LAGplus StructMod.X_EX(jj-nlag+1,:)];
    end
    
    %% STEP 2.2: generate artificial series
    % From observation nlag+1 to nobs, compute the artificial data
    for jj = nlag+1:nobs+nlag
        for mm = 1:nvars
            % Compute the value for time=jj
            y_artificial(jj,mm) = LAGplus * AMATt(1:end,mm) + u(jj-nlag,mm);
        end
        % now update the LAG matrix
        if jj<nobs+nlag
            LAG = [y_artificial(jj,:) LAG(1,1:(nlag-1)*nvars)];
            if const==0
                LAGplus = LAG;
            elseif const==1
                LAGplus = [1 LAG];
            elseif const==2
                LAGplus = [1 T(jj-nlag+1) LAG];
            elseif const==3
                LAGplus = [1 T(jj-nlag+1) T(jj-nlag+1).^2 LAG];
            end
            if nvars_ex~=0
                LAGplus = [LAGplus StructMod.X_EX(jj-nlag+1,:)];
            end
        end
    end

%% STEP 3: estimate VAR on artificial data.
    ReducedForm_draw = EstimReducedForm(y_artificial,EXOG,opt);    
    [StructMod_draw,opt] = StructuralForm(ReducedForm_draw,opt);
%% STEP 4: calculate "ndraws" impulse responses and store them
    irf_draw = IRFs(StructMod_draw,opt); % uses options from VARopt, but companion etc. from VAR_draw
    
    if ReducedForm_draw.maxEig<.9999 || opt.model == 2
        IRFpoint(:,:,:,tt) = irf_draw;
        tt=tt+1;
    end
end
disp('-- Done!');
disp(' ');

%% Compute the error bands
%===============================================
pctg_inf = (100-pctg)/2; 
pctg_sup = 100 - (100-pctg)/2;
IRFINF(:,:,:) = prctile(IRFpoint(:,:,:,:),pctg_inf,4);
IRFSUP(:,:,:) = prctile(IRFpoint(:,:,:,:),pctg_sup,4);
IRFMED(:,:,:) = prctile(IRFpoint(:,:,:,:),50,4);
IRFBAR(:,:,:) = mean(IRFpoint(:,:,:,:),4);
