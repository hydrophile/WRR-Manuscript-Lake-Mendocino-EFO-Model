classdef (Abstract) RuleFloodRls < handle
    % 6/10/2016
    % Developed by Chris Delaney
    % This is the super class for flood control rules.
    
    properties
        name                % Class name
        rlsFlood            % Flood release
        lakeMendoObj        % Lake Mendocino object
    end
    
    methods
        % CLASS CONSTRUCTOR
        function this = RuleFloodRls(name,lakeMendoObj)
            this.name = name;
            % Set the referenct to the Lake Mendo Object
            this.lakeMendoObj = lakeMendoObj;
        end
    end
    
    methods(Abstract)
        % GET FLOOD RELEASE
        getRlsFlood(this,vToday,timeStep,stor)
    end
    
end

