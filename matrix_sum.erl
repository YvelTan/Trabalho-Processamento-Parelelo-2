-module(matrix_sum).
-export([
    run/0,
    run_experiment/0,
    gerar_matriz/2,
    soma_sequencial/2,
    soma_paralela/3,
    medir_tempo/1
]).


run() ->
    io:format("~n=== EXPERIMENTO: SOMA DE MATRIZES PARALELA EM ERLANG ===~n~n"),
    run_experiment().

run_experiment() ->
   
    Tamanhos   = [100, 300, 500, 800, 1000],  
    NumProcs   = [1, 2, 4, 8, 16],             
    Repeticoes = 3,                             

    io:format("Tamanhos testados : ~w~n", [Tamanhos]),
    io:format("Processos testados: ~w~n", [NumProcs]),
    io:format("Repetições        : ~w~n~n", [Repeticoes]),

    
    io:format("~-6s ~-8s ~-14s ~-14s ~-10s ~-10s~n",
        ["N", "Workers", "Seq (ms)", "Par (ms)", "Speedup", "Eficiência"]),
    io:format("~s~n", [string:copies("-", 66)]),

    lists:foreach(fun(N) ->
        
        A = gerar_matriz(N, N),
        B = gerar_matriz(N, N),

        
        TSeq = media_tempo(fun() -> soma_sequencial(A, B) end, Repeticoes),

        lists:foreach(fun(W) ->
            
            TPar = media_tempo(fun() -> soma_paralela(A, B, W) end, Repeticoes),

            Speedup    = TSeq / TPar,
            Eficiencia = Speedup / W * 100,

            io:format("~-6w ~-8w ~-14.2f ~-14.2f ~-10.3f ~-9.1f%~n",
                [N, W, TSeq, TPar, Speedup, Eficiencia])
        end, NumProcs),

        io:format("~s~n", [string:copies("-", 66)])
    end, Tamanhos),

    io:format("~nExperimento concluído.~n").

gerar_matriz(Linhas, Cols) ->
    [[rand:uniform(100) || _ <- lists:seq(1, Cols)] || _ <- lists:seq(1, Linhas)].

soma_sequencial(A, B) ->
    lists:zipwith(fun(LinhaA, LinhaB) ->
        lists:zipwith(fun(X, Y) -> X + Y end, LinhaA, LinhaB)
    end, A, B).

soma_paralela(A, B, NumWorkers) ->
    Coords  = self(),

    
    ChunksA = dividir(A, NumWorkers),
    ChunksB = dividir(B, NumWorkers),

    
    IndexedChunks = lists:zip(lists:seq(0, length(ChunksA) - 1),
                              lists:zip(ChunksA, ChunksB)),

    lists:foreach(fun({Idx, {CA, CB}}) ->
        spawn(fun() ->
            Resultado = soma_sequencial(CA, CB),
            Coords ! {resultado, Idx, Resultado}
        end)
    end, IndexedChunks),

   
    NumChunks = length(ChunksA),
    Resultados = coletar(NumChunks, []),

    
    Ordenados = lists:sort(fun({I1,_},{I2,_}) -> I1 =< I2 end, Resultados),
    lists:append([Linhas || {_, Linhas} <- Ordenados]).

dividir(Lista, N) ->
    Tam   = length(Lista),
    Base  = Tam div N,
    Resto = Tam rem N,
    dividir_aux(Lista, N, Base, Resto, []).

dividir_aux([], _, _, _, Acc) ->
    lists:reverse(Acc);
dividir_aux(Lista, N, Base, Resto, Acc) when N > 0 ->
    
    TamChunk = if Resto > 0 -> Base + 1; true -> Base end,
    {Chunk, Restante} = lists:split(min(TamChunk, length(Lista)), Lista),
    dividir_aux(Restante, N - 1, Base, max(0, Resto - 1), [Chunk | Acc]).


coletar(0, Acc) -> Acc;
coletar(K, Acc) ->
    receive
        {resultado, Idx, Linhas} ->
            coletar(K - 1, [{Idx, Linhas} | Acc])
    after 30000 ->
        error(timeout_worker)
    end.


medir_tempo(Fun) ->
    T0 = erlang:monotonic_time(microsecond),
    Fun(),
    T1 = erlang:monotonic_time(microsecond),
    (T1 - T0) / 1000.0.   


media_tempo(Fun, N) ->
    Tempos = [medir_tempo(Fun) || _ <- lists:seq(1, N)],
    lists:sum(Tempos) / N.
