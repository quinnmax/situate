

% path containing results from situate runs. one path should contain results from a run on positive
% images, the other should contain results from a run on negative images.

% if there is more than one method run on the positive set, there should be matching methods run for
% the negative set. 

path_pos = '/Users/Max/Dropbox/Projects/situate/results/dogwalking, test, single attempt, positives';
path_neg = '/Users/Max/Dropbox/Projects/situate/results/dogwalking, negatives';

% path_pos = '/Users/Max/Dropbox/Projects/situate/results/dogwalking, stanford positives, single attempt';
% path_neg = '/Users/Max/Dropbox/Projects/situate/results/dogwalking, negatives';

% path_neg = '/Users/Max/Dropbox/Projects/situate/results/handshaking_handshaking, retest, negative_2017.10.26.11.20.06/';
% path_pos = '/Users/Max/Dropbox/Projects/situate/results/handshaking_handshaking, retest_2017.10.25.15.14.25/';

output_directory = 'results/';
if ~exist(output_directory,'dir')
    mkdir(output_directory);
end

show_example_workspaces = false;



%% load data

paths = {path_pos; path_neg};

fnames_temp = cell(1,length(paths));
for mi = 1:length(paths)
    fnames_temp{mi} = arrayfun( @(x) fullfile( paths{mi}, x.name ), dir( fullfile( paths{mi}, '*.mat' ) ), 'UniformOutput', false );
end

group_field = 'p_condition';
fnames = vertcat(fnames_temp{:});
%fnames(strcmp(fnames,'/Users/Max/Dropbox/Projects/situate/results/handshaking unsided, test, positives/uniform location and box, box adjust_fold_01_2017.09.09.14.58.56.mat')) = [];
temp = cellfun( @(x) load(x, group_field), fnames );
group_field_data = arrayfun( @(x) x.description, [temp.p_condition], 'UniformOutput', false );

[param_descriptions,~,IA,IB] = unique_cell( group_field_data );
workspaces_final  = cell(1,max(IA));
situation_support = cell(1,max(IA));
fnames_im_test    = cell(1,max(IA));

p_structs = [temp(IB).p_condition];

num_methods = max(IA);

for mi = 1:num_methods
    
    group_data = cellfun( @(x) load(x,'workspaces_final','fnames_im_test'), fnames( eq( mi, IA ) ) );
    temp = [group_data.workspaces_final];
    workspaces_final{mi}  = [temp{:}];
    situation_support{mi} = [workspaces_final{mi}.situation_support];
    
    temp                  = cellfun( @(x) reshape( x, 1, [] ), {group_data.fnames_im_test}, 'UniformOutput', false );
    fnames_im_test{mi}    = [temp{:}];
    
end

assert( ~isequal( {'a','b'}, {'a','b'}, {'b','a'} ) );
if length(fnames_im_test) > 1
    assert( isequal( fnames_im_test{:} ) );
end
fnames_im_test = fnames_im_test{1};
is_positive = [true(1,length(temp{1})), false(1,length(temp{2}))]; % pos first per def of paths;
num_images = length(is_positive);
% all methods should be using the same file names


%% generate ROC curves

AUROCs = zeros(1,num_methods);

figure;
for mi = 1:num_methods
    [AUROCs(mi), TPR, FPR, thresholds] = ROC( situation_support{mi}, is_positive );
    plot(FPR,TPR);
    hold on;
end
temp = cellfun( @(x,y) [x ' AUROC: ' y], param_descriptions, arrayfun( @num2str, AUROCs, 'UniformOutput', false ), 'UniformOutput', false);
legend(temp,'location','southeast');
xlabel('FPR');
ylabel('TPR');
title('ROC using situation support');

saveas(gcf, fullfile( output_directory, [[p_structs(1).situation_objects{:}] '_ROC.png'] ),'png')
    

%% generate precision recall with unique images

[~, ~, ~, unique_im_inds] = unique_cell(fnames_im_test);
include_inds = unique_im_inds;

figure;
for mi = 1:num_methods
    [precision, recall, thresholds] = PR( situation_support{mi}(include_inds), is_positive(include_inds) );
    plot(recall,precision);
    hold on;
end
legend(param_descriptions,'location','southeast');
xlabel('recall');
ylabel('precision');
xlim([0 1]);
ylim([0 1]);
title('PR using situation support (100+,400-)');

saveas(gcf,fullfile( output_directory, 'dogwalking pos neg PR unbalanced.png'),'png')
   
%% generate precision recall with balanced pos/neg images (repeat runs on positives)

pos_count = sum(is_positive);
neg_count = sum( 1 - is_positive );

if pos_count > neg_count
    include_inds = find(is_positive);
    include_inds = include_inds(1:neg_count);
    include_inds = [include_inds find(~is_positive)];
else
    include_inds = find(~is_positive);
    include_inds = include_inds(1:pos_count);
    include_inds = [include_inds find(is_positive)];
end

figure;
for mi = 1:num_methods
    [precision, recall, thresholds] = PR( situation_support{mi}(include_inds), is_positive(include_inds) );
    plot(recall,precision);
    hold on;
end
legend(param_descriptions,'location','southeast');
xlabel('recall');
ylabel('precision');
xlim([0 1]);
ylim([0 1]);
title('PR using situation support (400+,400-)');

fname = ['dogwalking pos neg PR balanced ' datestr(now,'yyyy_mm_dd_HH_MM_SS') '.png'];
saveas(gcf,fullfile( output_directory, fname ),'png');
    
%% top n

if show_example_workspaces

    [~, ~, ~, unique_im_inds] = unique_cell(fnames_im_test);
    include_inds = unique_im_inds;

    situation_support_sorted = cell(1,num_methods);
    is_positive_sorted       = cell(1,num_methods);
    fnames_sorted            = cell(1,num_methods);
    workspaces_sorted        = cell(1,num_methods);

    for mi = 1:num_methods
        
        situation_support_temp = situation_support{mi}(include_inds);
        is_positive_temp = is_positive(include_inds);
        fnames_temp = fnames_im_test(include_inds);
        workspaces_temp = workspaces_final{mi}(include_inds);

        [situation_support_sorted{mi}, sort_order] = sort(situation_support_temp,'descend');
        is_positive_sorted{mi} = is_positive_temp( sort_order );
        fnames_sorted{mi} = fnames_temp( sort_order );
        workspaces_sorted{mi} = workspaces_temp( sort_order );

    end

    % look at top 5 images by situation support
    n = 5;
    figure;
    for mi = 1:num_methods
    for ii = 1:n
        cur_im_ind = ii;
        subplot2(num_methods,n,mi,ii);
        cur_fname = fnames_sorted{mi}{cur_im_ind};

        % this is just fixing for max having updated directory names
        if ~exist(cur_fname,'file')
            [path,filename,ext] = fileparts( cur_fname );
            switch path
                case '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking_test'
                    new_path = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_test';
                case '/Users/Max/Documents/MATLAB/data/situate_images/dogwalking_negative_test'
                    new_path = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_negative';
                case '/Users/Max/Documents/MATLAB/data/situate_images/dogwalking_negative_validation'
                    new_path = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_negative';
                otherwise
                    error('file not found, path not fixed');
            end
            cur_fname = fullfile( new_path, [filename ext] );
        end

        situate.draw_workspace( cur_fname, p_structs(mi), workspaces_sorted{mi}(cur_im_ind) ) ;
        if ii == 1 && mi == 1, title('highest situation support'); end
        if ii == 1, ylabel(p_structs(mi).description); end
        xlabel(['situation support: ' num2str( situation_support_sorted{mi}(cur_im_ind) ) ]);
    end
    end
    set(gcf,'OuterPosition',[1,5,1680,1023]);
    saveas(gcf,fullfile( output_directory, 'tops, high situation support, all images.png'),'png');

    % look at bottom 5 images by situation support
    n = 5;
    figure;
    for mi = 1:num_methods
    for ii = 1:n
        cur_im_ind = length(fnames_sorted{mi}) - ii + 1;
        subplot2(num_methods,n,mi,ii);
        cur_fname = fnames_sorted{mi}{cur_im_ind};

        if ~exist(cur_fname,'file')
            [path,filename,ext] = fileparts( cur_fname );
            switch path
                case '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking_test'
                    new_path = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_test';
                case '/Users/Max/Documents/MATLAB/data/situate_images/dogwalking_negative_test'
                    new_path = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_negative';
                case '/Users/Max/Documents/MATLAB/data/situate_images/dogwalking_negative_validation'
                    new_path = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_negative';
                otherwise
                    error('file not found, path not fixed');
            end
            cur_fname = fullfile( new_path, [filename ext] );
        end

        situate.draw_workspace( cur_fname, p_structs(mi), workspaces_sorted{mi}(cur_im_ind) ) ;
        if ii == 1 && mi == 1, title('lowest situation support'); end
        if ii == 1, ylabel(p_structs(mi).description); end
        xlabel(['situation support: ' num2str( situation_support_sorted{mi}(cur_im_ind) ) ]);
    end
    end
    set(gcf,'OuterPosition',[1,5,1680,1023]);
    saveas(gcf,fullfile( output_directory, 'tops, low situation support, all images.png'),'png');

    % top false positives
    n = 5;
    figure;
    for mi = 1:num_methods
        temp_inds = find(~is_positive_sorted{mi}, n, 'first' );
    for ii = 1:min(n,length(temp_inds))
        cur_im_ind = temp_inds(ii);
        subplot2(num_methods,n,mi,ii);
        cur_fname = fnames_sorted{mi}{cur_im_ind};

        if ~exist(cur_fname,'file')
            [path,filename,ext] = fileparts( cur_fname );
            switch path
                case '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking_test'
                    new_path = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_test';
                case '/Users/Max/Documents/MATLAB/data/situate_images/dogwalking_negative_test'
                    new_path = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_negative';
                case '/Users/Max/Documents/MATLAB/data/situate_images/dogwalking_negative_validation'
                    new_path = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_negative';
                otherwise
                    error('file not found, path not fixed');
            end
            cur_fname = fullfile( new_path, [filename ext] );
        end

        %cur_fname = strrep(cur_fname,'_validation','_test');

        situate.draw_workspace( cur_fname, p_structs(mi), workspaces_sorted{mi}(cur_im_ind) ) ;
        if ii == 1 && mi == 1, title('highest situation support, non-target image'); end
        if ii == 1, ylabel(p_structs(mi).description); end
        xlabel(['situation support: ' num2str( situation_support_sorted{mi}(cur_im_ind) ) ]);
    end
    end
    set(gcf,'OuterPosition',[1,5,1680,1023]);
    saveas(gcf,fullfile( output_directory, 'tops, high situation support, negatives.png' ),'png');

    % top false negatives
    n = 5;
    figure;
    for mi = 1:num_methods
        temp_inds = find(is_positive_sorted{mi}, n, 'last' );
    for ii = 1:n
        cur_im_ind = temp_inds(ii);
        subplot2(num_methods,n,mi,ii);
        cur_fname = fnames_sorted{mi}{cur_im_ind};

        if ~exist(cur_fname,'file')
            [path,filename,ext] = fileparts( cur_fname );
            switch path
                case '/Users/Max/Documents/MATLAB/data/situate_images/PortlandSimpleDogWalking_test'
                    new_path = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_PortlandSimple_test';
                case '/Users/Max/Documents/MATLAB/data/situate_images/dogwalking_negative_test'
                    new_path = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_negative';
                case '/Users/Max/Documents/MATLAB/data/situate_images/dogwalking_negative_validation'
                    new_path = '/Users/Max/Documents/MATLAB/data/situate_images/DogWalking_negative';
                otherwise
                    error('file not found, path not fixed');
            end
            cur_fname = fullfile( new_path, [filename ext] );
        end

        %cur_fname = strrep(cur_fname,'_validation','_test');

        situate.draw_workspace( cur_fname, p_structs(mi), workspaces_sorted{mi}(cur_im_ind) ) ;
        if ii == 1 && mi == 1, title('lowest situation support, target image'); end
        if ii == 1, ylabel(p_structs(mi).description); end
        xlabel(['situation support: ' num2str( situation_support_sorted{mi}(cur_im_ind) ) ]);
    end
    end
    set(gcf,'OuterPosition',[1,5,1680,1023]);
    saveas(gcf,fullfile( output_directory, 'tops, low situation support, positives.png'),'png');

end



%% recall at n if each target image was alone

[unique_im_fnames, ~, IA, unique_im_inds] = unique_cell(fnames_im_test);
include_inds = unique_im_inds;

unique_target_inds = intersect(find(is_positive), unique_im_inds);
rank_if_only_target = zeros( num_methods, length( unique_target_inds ) );
for ci = 1:num_methods
    nontarget_support_vals = situation_support{ci}(~is_positive);
    for imi = 1:length(unique_target_inds)
    
        cur_target_support = situation_support{ci}(unique_target_inds(imi));
        rank_if_only_target(ci,imi) = sum( gt( nontarget_support_vals, cur_target_support ) );
        
    end
end


recall_at_vals   = 1:100;
mean_recall_at   = zeros( num_methods, length(recall_at_vals) );
median_rank    = zeros( num_methods, 1 );
for ci = 1:num_methods
    median_rank( ci ) = median( rank_if_only_target(ci,:) + 1 );
    for ni = 1:length(recall_at_vals)
        mean_recall_at(   ci, ni ) = mean(   rank_if_only_target(ci,:) < recall_at_vals(ni) );
    end
end
% should output a csv file or at least save off the mat
save( fullfile( output_directory, 'mean_recall_at_n.mat'), 'mean_recall_at','recall_at_vals', 'param_descriptions' );

for ci = 1:num_methods
    fprintf('method: %s \n', p_structs(ci).description );
    for ni = 1:length(recall_at_vals)
        fprintf('mean recall @%d:   %f\n', recall_at_vals(ni), mean_recall_at(ci,ni) );
    end
    fprintf('\n');
end

for ci = 1:num_methods
    fprintf('method: %s \n', p_structs(ci).description );
        fprintf('median rank:   %f\n', recall_at_vals(ni), median_rank(ci) );
    fprintf('\n');
end



%% output data to csv file

fname_out = fullfile( output_directory, ['average_recall_at_n_' datestr(now,'yyyy_mm_dd_HH_MM_SS') '.csv'] );
fid = fopen(fname_out,'w');

fprintf(fid, 'n, ');
fprintf(fid, '%d, ', recall_at_vals(1:end-1) ); 
fprintf(fid, '%d\n', recall_at_vals(end) ); 

for ci = 1:length(param_descriptions)
    cur_condition_desc = param_descriptions{ci};
    cur_condition_desc = strrep( cur_condition_desc, ',', '.' );
    fprintf(fid, '%s, ', cur_condition_desc);
    fprintf(fid, '%f, ', mean_recall_at(ci,1:end-1) );
    fprintf(fid, '%f\n', mean_recall_at(ci,end) );
end

fclose(fid);

%% output data to csv file

fname_out = fullfile( output_directory, ['median_rank' datestr(now,'yyyy_mm_dd_HH_MM_SS') '.csv'] );
fid = fopen(fname_out,'w');

fprintf(fid, 'n, ');
fprintf(fid, '%d, ', recall_at_vals(1:end-1) ); 
fprintf(fid, '%d\n', recall_at_vals(end) ); 

for ci = 1:length(param_descriptions)
    cur_condition_desc = param_descriptions{ci};
    cur_condition_desc = strrep( cur_condition_desc, ',', '.' );
    fprintf(fid, '%s, ', cur_condition_desc);
    fprintf(fid, '%f, ', median_rank(ci,1:end-1) );
    fprintf(fid, '%f\n', median_rank(ci,end) );
end

fclose(fid);





