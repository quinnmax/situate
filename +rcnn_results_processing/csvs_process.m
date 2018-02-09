function [confidences, gt_ious, boxes_xywh, output_labels, fnames_include] = csvs_process( csv_directory, fnames_include, testing_file_directory )
%[confidences, gt_ious, boxes_xywh, output_labels, per_row_fnames] = csvs_process( csv_directory, fnames_include, testing_file_directory )
%
%   csv_directory
%       top level, not the per-object directories
%       assumes directory format situation:object:image_file_name.csv
%       assumes column format 'x','y','w','h','confidence','gt iou maybe'
%       where gt iou is not reliable for situations with multiples of some objects
%   fnames_include
%       specifies the testing set
%   testing_file_directory
%       if fnames_include is empty, it will use files from this directory
%       if you want updated IOUs, label files will be necessary, and found here
%
%   confidences has rcnn confidences for each object (column) and image (row)
%   gt_ious are based on a comparison with the label files (if available)
%   output_labels specify which objects are in which column
%   per_row_fnames gives you the files that each row represents
    
    csv_data_columns = {'x','y','w','h','confidence','gt iou maybe'};
    csv_box_inds = 1:4;
    csv_conf_col = 5;
    csv_iou_col = 6;
    
    
    if ~exist('testing_file_directory','var')
        testing_file_directory = [];
    end
    
    if ~exist('fnames_include','var')
        fnames_include = [];
    end
    
    
    
    % get included classes from csv directory
    
    csv_dir_data = dir(csv_directory);
    csv_dir_data( strcmp( cellfun( @(x) x(1), {csv_dir_data.name},'UniformOutput',false), '.' ) ) = [];
    csv_classes = {csv_dir_data.name};
    
    % this identifies the situation
    % and for one of the handshaking formulations, 
    % gets ready to fix the two instances of each object issue
    
    switch [csv_classes{:}]
        
        % output_labels maps the folders in the csv directory to the situation_objects used by
        % situate. if one of the csv folders accounts for two situation objects (ie, players that
        % share a classifier) then both are listed, and the folder gets a >1 in its
        % instances_per_obj_in_situation entry
        
        case 'dogdog_walkerleash'
            situation = 'dogwalking';
            instances_per_obj_in_situation = [1 1 1];
            output_labels = {'dog','dogwalker','leash'};
            
        case 'handshakeperson_my_leftperson_my_right'
            situation = 'handshaking';
            instances_per_obj_in_situation = [1 1 1];
            output_labels = {'handshake','left','right'};
            
        case 'handshakeparticipant'
            situation = 'handshaking_unsided';
            instances_per_obj_in_situation = [1 2];
            output_labels = {'handshake','participant1','participant2'};
            
        case 'netplayer_my_leftplayer_my_righttable'
            situation = 'pingpong';
            instances_per_obj_in_situation = [1 1 1 1];
            output_labels = {'net','player1','player2', 'table'};
            
        otherwise
            error('unrecognized situation objects'); 
            
    end
    
    situation_struct = situate.load_situation_definitions( situation );
    
    
    
    
    % if fnames_include is empty, tries to get them from the testing_file_directory
    % if both are missing, use everything in the csv folder
    
    if isempty(fnames_include) && ~isempty(testing_file_directory)
        fnames_include = dir( fullfile( testing_file_directory, '*.jpg' ) );
        fnames_include = {fnames_include.name};
    end
    
    % switch fnames_include to csv names
    if ~isempty( fnames_include )
        fnames_include = cellfun( @(x) [x(1:findstr(x,'.')) 'csv'], fnames_include, 'UniformOutput', false );
    end
    
    % if fnames_include doesn't exist, we'll use everything in the csv directory
    if isempty(fnames_include)
        % include everything from the csv directory
        temp = dir( fullfile( csv_directory, csv_classes{1}, '*.csv' ) );
        fnames_include = {temp.name};
    end
    
    
    
    num_images = length(fnames_include);
    num_objects = sum( instances_per_obj_in_situation );
    
    boxes_xywh  =      cell( num_images, num_objects );
    confidences = nan( num_images, num_objects );
    gt_ious     = nan( num_images, num_objects );
    
    for fi = 1:num_images
       
        for oi = 1:length(instances_per_obj_in_situation)

            cur_csv_name = fullfile( csv_directory, csv_classes{oi}, fnames_include{fi} );
            temp_data = importdata( cur_csv_name );
            temp_data = sortrows(temp_data, -1 * csv_conf_col );
            
            for ii = 1:instances_per_obj_in_situation(oi)
                % should usually just be 1, but higher if there are repeat instances of an object
                destination_col = sum( instances_per_obj_in_situation( 1:(oi-1) ) ) + ii;
                boxes_xywh{ fi,destination_col} = temp_data(ii,csv_box_inds);
                confidences(fi,destination_col) = temp_data(ii,csv_conf_col); 
                gt_ious(    fi,destination_col) = temp_data(ii,csv_iou_col);   
            end
 
        end
        
        % update with reconciled ious
        if ~isempty(testing_file_directory)
        	label_fname = fullfile( testing_file_directory, [fnames_include{fi}(1:end-3) 'labl'] );
        else
            label_fname = [];
        end
        if exist(label_fname,'file')
            label_data = situate.labl_load( label_fname, situation_struct );
        else
            label_data = [];
        end
        
        if ~isempty(label_data)
            workspace = [];
            workspace.labels     = output_labels;
            workspace.boxes_xywh = vertcat(boxes_xywh{fi,:});
            workspace_updated    = situate.workspace_score( workspace, label_data, situation_struct );
            for wi = 1:length(workspace_updated.labels)
                destination_ind = strcmp( workspace_updated.labels{wi}, output_labels );
                gt_ious(fi,destination_ind) = workspace_updated.GT_IOU(wi);
            end
        end
        
        
    end
    
    gt_ious( gt_ious < 0 ) = nan;
     
end

    

    