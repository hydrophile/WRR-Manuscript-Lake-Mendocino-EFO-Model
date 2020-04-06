classdef RuleMaxRlsLmWfProxy < src.RuleMaxRls
    % 6/10/2016
    % Developed by John Mendoza
    % This class defines the max release rule for maintaining flows at 
    % Hopland below 8,000 cfs. This rule uses observed West Fork flows as a
    % proxy for predicting flows at Hopland.
    
    properties
        qMaxWf              % Maximum West Fork flow (Hopland proxy)
        rlsMaxWcm           % Max release schedule 
        lakeMendoObj        % Lake Mendocin object
    end
    
    methods
        % CLASS CONSTRUCTOR
        function this = RuleMaxRlsLmWfProxy...
                (name,rlsMaxWcm,qMaxWf,lakeMendoObj)
            % Call constructor of super class
            this = this@src.RuleMaxRls(name);
            % Initialize subclass variables
            % Convert elevations to storage
            this.rlsMaxWcm(:,1) = ...
                interp1(lakeMendoObj.hypElev,...
                lakeMendoObj.hypStor,...
                rlsMaxWcm(:,1),'pchip');
            this.rlsMaxWcm(:,2) = rlsMaxWcm(:,2);
            this.qMaxWf = qMaxWf;
            this.lakeMendoObj = lakeMendoObj;
        end
        
        % DETERMINE MAX FLOOD RELEASE
        function rlsFloodMax = getMaxRls(this,storLmPrev,qUiWf,qUiWfPrev)
            % Evaluate if current flood release exceeds max release
            rowMaxRls = find(this.rlsMaxWcm(:,1) < storLmPrev,1,'last');
            if isempty(rowMaxRls)
                rlsFloodMax = this.rlsMaxWcm(1,2);
            else
                rlsFloodMax = this.rlsMaxWcm(rowMaxRls,2);
            end
            % Evaluate flows at West Fork
            indxProxy = find(qUiWf < this.qMaxWf(:,1),1);            
            if qUiWf > qUiWfPrev
                rlsFloodMaxPrxy = this.qMaxWf(indxProxy,2);
            else
                if storLmPrev < this.rlsMaxWcm(3,1)
                    rlsFloodMaxPrxy = this.qMaxWf(indxProxy,3);
                else
                    rlsFloodMaxPrxy = this.qMaxWf(indxProxy,4);
                end
            end
            if rlsFloodMaxPrxy < rlsFloodMax
                rlsFloodMax = rlsFloodMaxPrxy;
            end
        end
        
        % CHECK FLOOD RELEASE AGAINST MAX
        function rlsFlood = checkRlsFlood(this,timeStep,rlsFloodProposed)
            % Get max flood release
            rlsFloodMax = this.getMaxRls...
                (this.lakeMendoObj.stor(timeStep-1,1),...
                this.lakeMendoObj.qUiWf(timeStep,1),...
                this.lakeMendoObj.qUiWf(timeStep-1,1));
            if rlsFloodProposed > rlsFloodMax
                rlsFlood = rlsFloodMax;
            else
                rlsFlood = rlsFloodProposed;
            end
        end
        
    end
    
end

