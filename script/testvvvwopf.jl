using GPSTTopic82024
using PowerModelsDistribution
using Ipopt
ipopt = Ipopt.Optimizer

file = "data/ENWLNW1F1/Master.dss"
eng4w = parse_file(file, transformations=[transform_loops!,remove_all_bounds!])
eng4w["settings"]["sbase_default"] = 1
reduce_line_series!(eng4w)
math4w = transform_data_model(eng4w, kron_reduce=false, phase_project=false)
add_start_vrvi!(math4w)


for (i,bus) in math4w["bus"]
    if bus["bus_type"] != 3 && !startswith(bus["source_id"], "transformer")
        bus["vm_pair_lb"] = [(1, 4, 0.9);(2, 4, 0.9);(3, 4, 0.9)]
        bus["vm_pair_ub"] = [(1, 4, 1.1);(2, 4, 1.1);(3, 4, 1.1)]
        # bus["grounded"] .=  0
    end
end

for (g,gen) in math4w["gen"]
    gen["cost"] = 0.0
end

function add_gens!(math4w)
    gen_counter = 2
    for (d, load) in math4w["load"]
        if mod(load["index"], 30) == 1
            phases = 3
            # phases = 1
            math4w["gen"]["$gen_counter"] = deepcopy(math4w["gen"]["1"])
            math4w["gen"]["$gen_counter"]["name"] = "$gen_counter"
            math4w["gen"]["$gen_counter"]["index"] = gen_counter
            math4w["gen"]["$gen_counter"]["cost"] = 1.0 #*math4w["gen"]["1"]["cost"]
            math4w["gen"]["$gen_counter"]["gen_bus"] = load["load_bus"]
            math4w["gen"]["$gen_counter"]["pmax"] = 5.0*ones(phases)
            math4w["gen"]["$gen_counter"]["pmin"] = 0.0*ones(phases)
            math4w["gen"]["$gen_counter"]["qmax"] = 50.0*ones(phases)
            math4w["gen"]["$gen_counter"]["qmin"] = -50.0*ones(phases)
            math4w["gen"]["$gen_counter"]["smax"] = 50.0*ones(phases)
            math4w["gen"]["$gen_counter"]["connections"] = [1:phases;4]
            gen_counter = gen_counter + 1
        end
    end
end
add_gens!(math4w)

vvc = GPSTTopic82024.voltvar_handle()
plot(0.85:0.01:1.15,vvc.(0.85:0.01:1.15))

res = solve_mc_vvvw_opf(math4w, ipopt)

# pg_cost = [gen["pg_cost"] for (g,gen) in res["solution"]["gen"]]

v_mag = [hypot.(bus["vr"],bus["vi"]) for (b,bus) in res["solution"]["bus"]]

