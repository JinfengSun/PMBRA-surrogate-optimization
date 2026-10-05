function hyp = Hypervolume_calculation(pf, repoint)
%HYPERVOLUME_CALCULATION Exact native-dimensional HV for minimization.
%   PF contains objective vectors and REPOINT is the dominated reference
%   point. The recursive slice calculation supports both the two- and
%   three-objective CEC2019 cases used in the manuscript.

    if isempty(pf)
        hyp = 0;
        return;
    end
    repoint = repoint(:).';
    if size(pf, 2) ~= numel(repoint)
        error('Hypervolume_calculation:DimensionMismatch', ...
            'The Pareto front and reference point must have the same dimension.');
    end

    points = pf(all(isfinite(pf), 2), :);
    points = points(all(points <= repoint, 2), :);
    points = RemoveDominated(unique(points, 'rows'));
    hyp = SliceHypervolume(points, repoint);
end

function volume = SliceHypervolume(points, reference)
    if isempty(points)
        volume = 0;
        return;
    end
    if size(points, 2) == 1
        volume = max(0, reference(1) - min(points(:,1)));
        return;
    end

    cuts = sort(unique([points(:,1); reference(1)]));
    volume = 0;
    for i = 1:numel(cuts)-1
        width = cuts(i+1) - cuts(i);
        if width <= 0, continue; end
        active = points(points(:,1) <= cuts(i), 2:end);
        active = RemoveDominated(unique(active, 'rows'));
        volume = volume + width * SliceHypervolume(active, reference(2:end));
    end
end

function result = RemoveDominated(points)
    if isempty(points)
        result = points;
        return;
    end
    keep = true(size(points,1), 1);
    for i = 1:size(points,1)
        if ~keep(i), continue; end
        has_dominator = any(all(points <= points(i,:), 2) & ...
            any(points < points(i,:), 2));
        if has_dominator
            keep(i) = false;
        end
    end
    result = points(keep, :);
end
