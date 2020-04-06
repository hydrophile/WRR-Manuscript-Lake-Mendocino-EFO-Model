classdef RuleMaxRlsLmEfo < src.RuleMaxRls
    % 11/21/16 This class estimates the maximum allowable release for the 
    % for Ensemble Forecast Operations (EFO) alternative. Max releas is
    % calculated based on forecasted flows at the Hopland junction.  
    
    properties
        qMaxHop             % Maximum Hopland flow
        rlsMaxWcm           % Maximum flow schedule
        lakeMendoObj        % Lake Mendocino object
    end
    
    methods
        % CLASS CONSTRUCTOR
        function this = RuleMaxRlsLmEfo...
                (name,rlsMaxWcm,qMaxHop,lakeMendoObj)
            % Call constructor of super class
            this = this@src.RuleMaxRls(name);
            % Initialize subclass variables
            this.rlsMaxWcm(:,1) = ...
                interp1(lakeMendoObj.hypElev,...
                lakeMendoObj.hypStor,...
                rlsMaxWcm(:,1),'pchip');
            this.rlsMaxWcm(:,2) = rlsMaxWcm(:,2);
            this.qMaxHop = qMaxHop;
            this.lakeMendoObj = lakeMendoObj;
        end
        
        
        % DETERMINE MAX FLOOD RELEASE
        function rlsFloodMax = getMaxRls(this,storLmPrev,rlsSpill,rlsEmgc,qUiHopFut,qUiWfFut,tsFutr)
            % Evaluate if current flood release exceeds max release
            rowMaxRls = find(this.rlsMaxWcm(:,1) < storLmPrev,1,'last');
            if isempty(rowMaxRls)
                rlsFloodMax = this.rlsMaxWcm(1,2);
            else
                rlsFloodMax = this.rlsMaxWcm(rowMaxRls,2);
            end
            % Evaluate flows at Hopland assuming no flood release
            qHopEod = qUiHopFut + qUiWfFut + rlsSpill + rlsEmgc;
            % Flows at Hopland exceed maximum for making flood releases
            rlsMaxHop = this.qMaxHop(tsFutr) - qHopEod;
            if rlsMaxHop < 0
                rlsFloodMax = 0;
            elseif rlsFloodMax > rlsMaxHop
                rlsFloodMax = rlsMaxHop;
            end
        end
        
    end
    
end

