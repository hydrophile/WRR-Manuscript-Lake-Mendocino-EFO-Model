classdef RuleFloodEfo < src.RuleFloodRls
    % 11/21/2016
    % Developed by Chris Delaney
    % This subClass defines Lake Mendocino flood operations for the
    % Ensemble Forecast Operations (EFO) alternative developed by Chris 
    % Delaney of the Sonoma Water.  This methodology evaluates future
    % risk of the reservoir exceeding a user defined storage threshold.
    % Flood releases are set by determining a release that satisfies a
    % risk tolerance curve.
    
    properties
        storThresh              % Lake Mendocino storage threshold (ac-ft)
        forecastDate            % Forecast dates for hindcasts (vector date)
        forecastMatrix          % Hindcasts (cfs): Col1 = Lake Mendo, Col2 = West Fork, Col3 = Hopland
        riskTolerance           % Risk tolerance curve (%)
        timeStepRls             % Simulated forecast horizon that sets the release (day)
        memberRls               % Simulated ensemble member that sets teh release
        rlsAvePvp               % Hydrograph of average annual PVP diversions (cfs)
        lossAveLmTot            % Hydrograph of average annual loss upstream of Lake Mendocino (cfs)
        nFutrTs                 % Number forecast horizon time steps
        nEnsMembers             % Number of ensemble members
        constants               % Model constants
        ruleMaxRls              % Maximum release rule object
        ruleRampRate            % Ramp rate rule object
        % Variable used for generating graphs
        storFutr                % Simulated future storage (ac-ft)
        storFutrPreRls          % Simulated fugure storage befor release applied (ac-ft)
        memberRlsPerTs          % Ensember member of release for each forecast horizon
        pctAbvThresh            % Percent ensemble members above storage threshold (%)
        pctAbvThreshPreRls      % Percent members above threshold before release (%)
        rlsFutr                 % Release forecast for all ensemble member and horizons (cfs)
        rlsMaxPerTs             % Maximum day 1 release per forecast horizon (cfs)
        rlsMaxLimit             % Release limit for all ensemble members and horizons (cfs)
        iRiskyMembers           % Boolean of risky ensemble members
        rlsNoConstraint         % Release forecast assuming no downstream constraints (cfs)
    end
    
    methods
        % CLASS CONSTRUCTOR
        function this = RuleFloodEfo...
                (name,forecastMatrix,inputData,lakeMendoObj,constants)
            % Call constructor of super class
            this = this@src.RuleFloodRls(name,lakeMendoObj);
            % Set the Dam Safety Storage Threshold
            this.storThresh = inputData.DamSafetyStorageThreshold;
            % Potter Valley Project Average Releases for Forecasting
            this.rlsAvePvp = inputData.PvpAveReleaseTbl.PvpAveRelease;
            % Initialize input variables for subclass
            this.forecastDate = inputData.ForecastDate;
            this.forecastMatrix = forecastMatrix;
            this.riskTolerance = inputData.RiskThreshold;
            this.constants = constants;
            % Set number of future time steps to be evaluated and number of
            % ensemble members
            [this.nFutrTs,this.nEnsMembers] = size(this.forecastMatrix{1,1});
            % Add 1 because timestep zero will be index 1
            this.nFutrTs = this.nFutrTs + 1;
            % Initialize model calculated variables
            this.timeStepRls(1:this.constants.nTimeSteps,1) = NaN;
            this.memberRls(1:this.constants.nTimeSteps,1) = NaN;
        end
        
        % ADD MAX RELEASE OBJECT
        function this = addRuleMaxRls(this,ruleMaxRls)
            this.ruleMaxRls = ruleMaxRls;
        end
        
        function this = addRuleRampRate(this,ruleRampRate)
            this.ruleRampRate = ruleRampRate;
        end
        
        % CALCULATE FLOOD RELEASES USING THE RISK BASED APPROACH
        function rlsFlood = getRlsFlood(this,vToday,timeStep)
            
            % Create future flow variable from cell array
            qForecastLM(2:this.nFutrTs,:) = this.forecastMatrix{timeStep,1}(1:this.nFutrTs-1,:);
            qForecastWF(2:this.nFutrTs,:) = this.forecastMatrix{timeStep,2}(1:this.nFutrTs-1,:);
            qForecastHop(2:this.nFutrTs,:) = this.forecastMatrix{timeStep,3}(1:this.nFutrTs-1,:);
            
            % Get today's evap to use for storage forecast
            lossFutrEvap = this.lakeMendoObj.lossEvap(timeStep,1);
            
            %Initialize variables
            this.storFutr(1:this.nFutrTs,1:this.nEnsMembers,1:(this.nFutrTs-1)) = NaN;
            % Set all ensembles initial storage to the previous day
            this.storFutr(1,1:this.nEnsMembers,1) = ...
                this.lakeMendoObj.stor(timeStep-1);
            this.storFutrPreRls = this.storFutr;
            this.pctAbvThresh(2:this.nFutrTs,1) = NaN;
            this.pctAbvThreshPreRls = this.pctAbvThresh;
            
            % To start assume all ensemble members violate the risk threshold
            colRisky(1,:) = 1:this.nEnsMembers;
            colRiskySelect(1,:) = 1:this.nEnsMembers;
            % This flag can only be turned off if releases are maxed out therefore we
            % are doing the best we can for releases and we give it a free pass
            iRiskyCheck(1,1:this.nEnsMembers) = true;
            % Initialize future flood releases to zero
            this.rlsFutr(1:this.nFutrTs,1:this.nEnsMembers,1:(this.nFutrTs-1)) = 0;
            this.rlsMaxLimit(1:this.nFutrTs,1:this.nEnsMembers,1:(this.nFutrTs-1)) = NaN;
            this.rlsNoConstraint(1:this.nFutrTs,1:this.nEnsMembers,1:(this.nFutrTs-1)) = NaN;
            storAbvThresh(1:this.nFutrTs,1:this.nEnsMembers) = 0;
            stor2Rls(1:this.nFutrTs,1:this.nEnsMembers) = 0;
            this.memberRlsPerTs(1:this.nFutrTs,1) = NaN;
            this.rlsMaxPerTs(1:this.nFutrTs,1) = NaN;
            iRisky(1,1:this.nEnsMembers) = false;
            this.iRiskyMembers(1:this.nFutrTs,1:this.nEnsMembers) = false;
            for tsFutrEnd = 2:this.nFutrTs
                if tsFutrEnd > 2
                    this.storFutr(:,:,tsFutrEnd-1) = this.storFutr(:,:,tsFutrEnd-2);
                end
                % Create date filters for data
                nDateFutr = datenum(vToday) + tsFutrEnd - 1;
                vDateFutr = datevec(nDateFutr);
                rowDayOfYear = find(this.constants.vDateYear(:,1) == vDateFutr(1,2) &...
                    this.constants.vDateYear(:,2) == vDateFutr(1,3));
                % Iterate throught the risky ensember members to calculate
                % storage with the proposed releases. To start with we assume
                % that all ensemble members are risky.
                for j = 1:this.nEnsMembers
                    % Calculate future storages (assume min compliance release)
                    this.storFutr(tsFutrEnd,colRiskySelect(j),tsFutrEnd-1) = this.getStorage(...
                        this.storFutr(tsFutrEnd-1,colRiskySelect(j),tsFutrEnd-1),...
                        this.rlsFutr(tsFutrEnd,colRiskySelect(j),tsFutrEnd-1),...
                        qForecastLM(tsFutrEnd,colRiskySelect(j)) + this.rlsAvePvp(rowDayOfYear,1), ...
                        this.lakeMendoObj.lossLmTot(rowDayOfYear,1), ...
                        lossFutrEvap ...
                        );
                end
                % Save the initial storage
                this.storFutrPreRls(:,:,tsFutrEnd-1) = this.storFutr(:,:,tsFutrEnd-1);
                % To start with we assume to we violate the risk threshold
                risky = true;
                while risky == true
                    % Evaluate if percentages violate risk thresholds and calculate
                    % flood releases if we exceed the risk threshold
                    iRisky = this.storFutr(tsFutrEnd,:,tsFutrEnd-1) > ...
                        this.storThresh & iRiskyCheck;
                    this.pctAbvThresh(tsFutrEnd,1) = sum(iRisky)/this.nEnsMembers;
                    if this.pctAbvThresh(tsFutrEnd,1) > this.riskTolerance(tsFutrEnd,1)
                        this.pctAbvThreshPreRls(tsFutrEnd,1) = this.pctAbvThresh(tsFutrEnd,1);
                        % Initialize iRiskyCheck assuming releases not maxed out
                        iRiskyCheck = iRisky;
                        % Get the columns of the members that exceed the risk threshold
                        [~,colRisky] = find(this.storFutr(tsFutrEnd,:,tsFutrEnd-1) > ...
                            this.storThresh);
                        % Calculate the release required for each ensemble member that
                        % exceeds the risk threshold.
                        % First figure out how many we need in order to comply
                        % with the rish threshold.
                        nMembers2Reduce = length(colRisky) - ...
                            floor(this.riskTolerance(tsFutrEnd,1)*this.nEnsMembers);
                        % Then sort by the amount above the risk threshold from
                        % smallest to largest to just pick the smallest storage
                        % exceedances to set future release for.
                        storAbvThresh(tsFutrEnd,colRisky) = ...
                            this.storFutr(tsFutrEnd,colRisky,tsFutrEnd-1) - this.storThresh;
                        [~,colSorted] = sort(storAbvThresh(tsFutrEnd,colRisky));
                        colRiskySelect = colRisky(1,colSorted(1,1:nMembers2Reduce));
                        this.iRiskyMembers(tsFutrEnd,colRiskySelect) = true;
                        stor2Rls(tsFutrEnd,colRiskySelect) = ...
                            this.storFutr(tsFutrEnd,colRiskySelect,tsFutrEnd-1) - this.storThresh+1;
                        % Calculate the max release contraints for future conditions.
                        % Determine releases for all members that exceed the threshold
                        % and then only select the smallest necessary to add to the
                        % rlsFloodFutrSelect release table.
                        for j = 1:length(colRiskySelect)
                            % Initialize the release to equally distribute among future days
                            selectRlsFloodFutr(2:tsFutrEnd,1) = ...
                                (sum(stor2Rls(:,colRiskySelect(j))))*this.constants.af2cfs/(tsFutrEnd-1);
                            % Save the no constraint release for plotting
                            this.rlsNoConstraint(2:tsFutrEnd,colRiskySelect(j),(tsFutrEnd-1)) = ...
                                selectRlsFloodFutr(2:tsFutrEnd,1);
                            rlsMaxLimitPrev(1:tsFutrEnd,1) = NaN;
                            while any((rlsMaxLimitPrev(2:tsFutrEnd,1) - ...
                                    this.rlsMaxLimit(2:tsFutrEnd,colRiskySelect(j),tsFutrEnd-1) ~= 0))
                                rlsMaxLimitPrev(1:tsFutrEnd,1) = ...
                                    this.rlsMaxLimit(1:tsFutrEnd,colRiskySelect(j),tsFutrEnd-1);
                                for i = 2:tsFutrEnd
                                    % Calculate Max Release
                                    if isa(this.ruleMaxRls,'src.RuleMaxRls')
                                        this.rlsMaxLimit(i,colRiskySelect(j),tsFutrEnd-1) = ...
                                            this.ruleMaxRls.getMaxRls(...
                                            this.storFutr(i-1,colRiskySelect(j),tsFutrEnd-1),...
                                            this.lakeMendoObj.rlsSpill(timeStep,1),...
                                            this.lakeMendoObj.rlsEmgc(timeStep,1),...
                                            qForecastHop(i,colRiskySelect(j)),...
                                            qForecastWF(i,colRiskySelect(j)),...
                                            i-1);
                                    else
                                        this.rlsMaxLimit(i,colRiskySelect(j),tsFutrEnd-1) = Inf;
                                    end
                                end
                                % See if release exceeds max and if so then redistribute
                                carryOver = 0;
                                for i = tsFutrEnd:-1:2
                                    selectRlsFloodFutr(i,1) = selectRlsFloodFutr(i,1) + carryOver;
                                    selectRlsCheck = selectRlsFloodFutr(i,1);
                                    if selectRlsFloodFutr(i,1) > this.rlsMaxLimit(i,colRiskySelect(j),tsFutrEnd-1)
                                        selectRlsFloodFutr(i,1) =  this.rlsMaxLimit(i,colRiskySelect(j),tsFutrEnd-1);
                                    end
                                    % Check for ramping restrictions
                                    if isa(this.ruleRampRate,'src.RuleRampRate')
                                        vDateStep = datevec(datenum(vToday)+i-1);
                                        if i < tsFutrEnd
                                            [rampAdjust,~] = this.ruleRampRate.getAjustedRls(...
                                                vDateStep,...
                                                selectRlsFloodFutr(i+1,1),...
                                                selectRlsFloodFutr(i,1)...
                                                );
                                            selectRlsFloodFutr(i,1) = ...
                                                selectRlsFloodFutr(i,1) + selectRlsFloodFutr(i+1,1) - rampAdjust;
                                        end
                                    end
                                    % Readjust carryover
                                    carryOver = ...
                                        max(0,carryOver + (selectRlsCheck - selectRlsFloodFutr(i,1))/(i-2));
                                end
                                % Recalculate storage
                                for i = 2:tsFutrEnd
                                    this.storFutr(i,colRiskySelect(j),tsFutrEnd-1) = this.getStorage(...
                                        this.storFutr(i-1,colRiskySelect(j),tsFutrEnd-1),...
                                        selectRlsFloodFutr(i,1),...
                                        qForecastLM(i,colRiskySelect(j)) + this.rlsAvePvp(rowDayOfYear,1), ...
                                        this.lakeMendoObj.lossLmTot(rowDayOfYear,1), ...
                                        lossFutrEvap ...
                                        );
                                end
                            end
                            % If scheduled releases don't remove the required amount
                            % of water to bring storage below the storage threshold
                            % then give it a free pass due to release constraints
                            if sum(selectRlsFloodFutr(:,1))*this.constants.cfs2af < sum(stor2Rls(:,colRiskySelect(j)))
                                iRiskyCheck(1,colRiskySelect(j)) = false;
                                % Didn't release enough so adjust the stor2Rls to how
                                % much was released
                                stor2Rls(tsFutrEnd,colRiskySelect(j)) = ...
                                    stor2Rls(tsFutrEnd,colRiskySelect(j)) - ...
                                    (sum(stor2Rls(:,colRiskySelect(j))) - ...
                                    sum(selectRlsFloodFutr(:,1))*this.constants.cfs2af);
                            end
                            % Set the future release to the calculate release schedule
                            this.rlsFutr(1:tsFutrEnd,colRiskySelect(j),tsFutrEnd-1) = ...
                                selectRlsFloodFutr(:,1);
                        end
                        %                         tsFutrBgn = 2;
                        risky = true;
                    else
                        % The current timeStepEnd is no longer risky therefore we can
                        % now iterate to the next timeStepEnd
                        if isnan(this.pctAbvThreshPreRls(tsFutrEnd,1))
                            this.pctAbvThreshPreRls(tsFutrEnd,1) = this.pctAbvThresh(tsFutrEnd,1);
                        end
                        clear colRisky colRiskySelect iRiskyCheck;
                        colRisky(1,:) = 1:this.nEnsMembers;
                        colRiskySelect(1,:) = 1:this.nEnsMembers;
                        iRiskyCheck(1,1:this.nEnsMembers) = true;
                        risky = false;
                    end
                end
            end
            % Calculate the flood release for the current time step by taking the max
            % estimated release needed to comply with the risk threshold for all future
            % time steps
            rlsToday(:,:) = this.rlsFutr(2,:,:);
            if any(rlsToday(:) > 0)
                rlsFlood = max(rlsToday(:));
                [rlsMaxMember,rlsMaxTs] = find(rlsToday == rlsFlood);
                [this.timeStepRls(timeStep,1),row] = min(rlsMaxTs);
                this.memberRls(timeStep,1) = rlsMaxMember(row);
                [this.rlsMaxPerTs,this.memberRlsPerTs] = ...
                    max(rlsToday);
                iZero = this.rlsMaxPerTs == 0;
                this.memberRlsPerTs(:,iZero) = NaN;
                this.rlsMaxPerTs = this.rlsMaxPerTs';
                this.memberRlsPerTs = this.memberRlsPerTs';
            else
                rlsFlood = 0;
                this.timeStepRls(timeStep,1) = NaN;
                this.memberRls(timeStep,1) = NaN;
            end
            
        end
        
        function stor = getStorage(this,storPrev,rlsCur,qIn,qLoss,lossEvap)
            stor =...
                storPrev...
                + qIn*this.constants.cfs2af ...
                - qLoss*this.constants.cfs2af ...
                - lossEvap ...
                - rlsCur*this.constants.cfs2af;
            
        end
        
    end
    
end

