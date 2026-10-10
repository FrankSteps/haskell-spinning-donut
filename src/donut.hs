{-
    SOBRE ESTE PROJETO:

    Reproduzindo o famoso algoritmo escrito em C por Andy Sloane do toroide (donut) no terminal. 
    A escolha do Haskell foi uma escolha devido ao paradigma funcional e ao seu uso na computação teórica.

    ------------------------------------------------------------------------------------------------------------------------------------------------

    SOBRE O USO DE INTELIGÊNCIA ARTIFICIAL:

    Modelos usados: Claude Haiku 4.5
    
    A inteligência artificial foi utilizada APENAS como ferramenta de apoio durante o desenvolvimento deste projeto, principalmente para esclarecer
    dúvidas de sintaxe, revisão da estrutura, correção de lógica, planejamento e na correção de erros de português nos comentários. 
    
    A implementação, as decisões tomadas no desenvolvimento e a compreensão do funcionamento do código são de responsabilidade do autor.

    ------------------------------------------------------------------------------------------------------------------------------------------------

    CÓDIGO OFICIAL DISPONIBILIZADO EM: https://www.a1k0n.net/2011/07/20/donut-math.html

    ------------------------------------------------------------------------------------------------------------------------------------------------

    COMPILE COM: ghc -O2 -outputdir builds -o builds/donut src/donut.hs && ./builds/donut
-}

-- importando bibliotecas para o projeto
import Data.Array ((!), accumArray)
import Control.Concurrent (threadDelay)
import System.IO (stdout, hFlush)


-- Vetor no R³ e Matriz [a_ij]_3x3 (uma matriz 3 por 3)
data Vector_3 = Vector_3 Double Double Double
type Matrix_3x3 = (Vector_3, Vector_3, Vector_3)



{-
    OPERAÇÃO ENTRE MATRIZES E VETORES
-}

-- Multiplicação entre vetores
dot :: Vector_3 -> Vector_3 -> Double
dot (Vector_3 a b c) (Vector_3 x y z) = a*x + b*y + c*z

-- Multiplica uma matriz por um vetor
mulVector :: Matrix_3x3 -> Vector_3 -> Vector_3
mulVector (row1, row2, row3) v = Vector_3 (dot row1 v) (dot row2 v) (dot row3 v)



{-
    OPERAÇÕES PARA ARFAGEM, ROLAGEM E GUINADA
-}

-- Rotaciona em X: Arfagem
-- Rotação em torno do eixo X (arfagem)
pitch :: Double -> Matrix_3x3
pitch theta =
        ( 
            Vector_3 1  0     0,
            Vector_3 0  c  (-s),
            Vector_3 0  s     c
        )
        where
            c = cos theta
            s = sin theta

{-
Rotaciona em Y: Rolagem

roll :: Double -> Matrix_3x3
roll theta = (
               Vector_3  1    0    0, 
               Vector_3  0    c    s, 
               Vector_3  0   (-s)  c
            ) 
            where c = cos theta; s = sin theta
-}

-- Rotação em torno do eixo Z (guinada)
yaw :: Double -> Matrix_3x3
yaw theta =
        ( 
            Vector_3 c   (-s) 0, 
            Vector_3 s    c   0,
            Vector_3 0    0   1
        )
        where
            c = cos theta
            s = sin theta


{-
    CONSTANTES GLOBAIS PARA O PROGRAMA
-}

-- tamanho da tela
screenWidth, screenHeight :: Int
screenWidth = 80; screenHeight = 30

-- r1 e r2 do toroide
r1, r2 :: Double
r1 = 1; r2 = 2;

-- constantes de controle da projeção
-- uso de fromIntegral para permitir a divisão entre tipos diferentes (Int e Double)
k1, k2 :: Double
k2 = 5; k1 = fromIntegral screenWidth * k2 * 3 / (8 * (r1 + r2))



{-
    Responsável por formar a lista que informa a posição dos pontos da superfície do donut (toroide) e o vetor normal antes de qualquer operação.
    Posteriormente, essa lista de tuplas (posição, normal) será usada para projetar, iluminar e rotacionar o toroide. 
-}
torus :: [(Vector_3, Vector_3)]
torus =
        [ ( 
            Vector_3 (dist * cosPhi) (r1 * sinTheta) (dist * sinPhi), 
            Vector_3 (cosTheta * cosPhi) sinTheta (cosTheta * sinPhi)
          ) | i <- [0 .. 89], j <- [0 .. 314], 
          let theta    = 0.07 * fromIntegral i
              phi      = 0.02 * fromIntegral j
              cosTheta = cos theta
              sinTheta = sin theta
              cosPhi   = cos phi
              sinPhi   = sin phi
              dist     = r2 + r1 * cosTheta
        ]



frame :: Double -> Double -> String
frame angleX angleZ = 
    unlines [[snd (frameBuffer ! (row, column)) | column <- [0 .. screenWidth-1 ]] | row <- [0 .. screenHeight-1]]
    where
        -- gira primeiro em X e depois em Z (vale para pontos e normais)
        rotate vector = mulVector (yaw angleZ) (mulVector (pitch angleX) vector)

        lightDirection = Vector_3 1 0 (-1)
        shades = ".,-~:;=!*#$@"

        -- cada fragmento: ((linha, coluna), (1/z, caractere))
        fragments = 
            [
                ((screenRow, screenColumn), (oneOverZ, shades !! shadeIndex)) | (point, normal) <- torus,
                let Vector_3 rotatedX rotatedY rotatedZ = rotate point
                    oneOverZ = 1 / (rotatedZ + k2)
                    screenColumn = floor (fromIntegral screenWidth / 2 + k1 * oneOverZ * rotatedX )
                    screenRow = floor (fromIntegral screenHeight / 2 - k1 * oneOverZ * rotatedY * 0.5)
                    luminance    = dot lightDirection (rotate normal)
                    shadeIndex   = floor (luminance * 8), 
                    luminance > 0,
                    screenColumn >= 0, screenColumn < screenWidth,
                    screenRow >= 0, screenRow < screenHeight
            ]

        -- Z-buffer: cada célula da tela começa vazia e acumula os fragmentos que caem nela,
        -- usando keepNearest para decidir qual deles fica
        frameBuffer = accumArray keepNearest (0, ' ') ((0,0), (screenHeight - 1, screenWidth - 1)) fragments

        -- Compara dois fragmentos da mesma célula pelo 1/z (maior = mais perto)
        keepNearest oldFragment newFragment =
            if fst newFragment > fst oldFragment then newFragment else oldFragment

{-
    Função principal e impura responsável por mostrar o resultado na tela
-}
main :: IO ()
main = do
  putStr "\ESC[2J"
  mapM_ draw (zip [0, 0.04 ..] [0, 0.02 ..])
  where
    draw (a, b) = do
      putStr ("\ESC[H" ++ frame a b)
      hFlush stdout
      threadDelay 30000 