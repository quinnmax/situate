function records = records_update( records, iteration, workspace_snapshot, p, current_agent_snapshot )
            
    % update record of scouting behavior
    records.workspace_record(iteration) = workspace_snapshot;
    current_agent_snapshot_lean = [];
    current_agent_snapshot_lean.type            = uint8( find(strcmp(current_agent_snapshot.type, records.agent_types ) ) );
    current_agent_snapshot_lean.interest        = uint8( find( strcmp( current_agent_snapshot.interest, p.situation_objects )));
    current_agent_snapshot_lean.box.r0rfc0cf    = current_agent_snapshot.box.r0rfc0cf;
    current_agent_snapshot_lean.support         = current_agent_snapshot.support;
    current_agent_snapshot_lean.workspace.objects = cellfun( @(x) find(strcmp(x,p.situation_objects)), workspace_snapshot.labels );
    current_agent_snapshot_lean.workspace.total_support = workspace_snapshot.total_support;
    records.agent_record(iteration)                     = current_agent_snapshot_lean;

    % population of agent types
    if iteration == 1
        records.population_count = zeros(1,length(records.agent_types));
        records.population_count = records.population_count + strcmp(current_agent_snapshot.type,records.agent_types);
    else
        records.population_count(iteration,:) = records.population_count(iteration-1,:) + strcmp(current_agent_snapshot.type,records.agent_types);
    end
    
end